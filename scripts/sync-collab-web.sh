#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
OMP_REPO="${OMP_REPO:-https://github.com/can1357/oh-my-pi.git}"
OMP_REF="${OMP_REF:-main}"
OMP_SOURCE="${OMP_SOURCE:-}"
CACHE_DIR="${CACHE_DIR:-$ROOT/.cache/omp-git}"
BUILD_DIR="${BUILD_DIR:-$ROOT/.cache/omp-build}"
PATCH_FILE="$ROOT/patches/omp-collab-web-current-origin.patch"

require_cmd() {
	if ! command -v "$1" >/dev/null 2>&1; then
		echo "sync-collab-web: missing required command: $1" >&2
		exit 1
	fi
}

require_cmd bun
require_cmd git
require_cmd tar

rm -rf "$BUILD_DIR"
mkdir -p "$BUILD_DIR"

if [[ -n "$OMP_SOURCE" ]]; then
	if [[ ! -d "$OMP_SOURCE/packages/collab-web" ]]; then
		echo "sync-collab-web: OMP_SOURCE must point at an omp repo checkout" >&2
		exit 1
	fi
	echo "sync-collab-web: using local source $OMP_SOURCE"
	(
		cd "$OMP_SOURCE"
		tar --exclude .git -cf - .
	) | tar -xf - -C "$BUILD_DIR"
else
	if [[ ! -d "$CACHE_DIR/.git" ]]; then
		echo "sync-collab-web: cloning $OMP_REPO into $CACHE_DIR"
		mkdir -p "$(dirname "$CACHE_DIR")"
		git clone --filter=blob:none "$OMP_REPO" "$CACHE_DIR"
	fi
	echo "sync-collab-web: fetching $OMP_REF from $OMP_REPO"
	git -C "$CACHE_DIR" fetch --depth=1 origin "$OMP_REF"
	git -C "$CACHE_DIR" archive FETCH_HEAD | tar -x -C "$BUILD_DIR"
fi

git -C "$BUILD_DIR" init -q

if grep -q "function defaultRelayUrlForBareLink" "$BUILD_DIR/packages/collab-web/src/lib/link.ts"; then
	echo "sync-collab-web: current-origin bare-link behavior already present upstream"
else
	echo "sync-collab-web: applying $PATCH_FILE"
	git -C "$BUILD_DIR" apply --check "$PATCH_FILE"
	git -C "$BUILD_DIR" apply "$PATCH_FILE"
fi

echo "sync-collab-web: installing omp workspace dependencies"
(
	cd "$BUILD_DIR"
	bun install --frozen-lockfile
)

echo "sync-collab-web: testing collab-web link parser"
(
	cd "$BUILD_DIR/packages/collab-web"
	bun test test/link.test.ts
	bun --eval '
		import { encodeBase64Url, parseCollabLink } from "./src/lib/link.ts";
		const room = "AbCdEf123456_-Xy";
		const key = encodeBase64Url(Uint8Array.from({ length: 32 }, (_, i) => i));
		Object.defineProperty(globalThis, "location", {
			configurable: true,
			value: { protocol: "https:", host: "omp.snd.one" },
		});
		const parsed = parseCollabLink(`${room}.${key}`);
		if ("error" in parsed) throw new Error(parsed.error);
		if (parsed.wsUrl !== `wss://omp.snd.one/r/${room}`) {
			throw new Error(`unexpected wsUrl: ${parsed.wsUrl}`);
		}
	'
)

echo "sync-collab-web: building collab-web"
(
	cd "$BUILD_DIR/packages/collab-web"
	bun run build
)

echo "sync-collab-web: replacing Worker assets"
rm -rf "$ROOT/public"
cp -R "$BUILD_DIR/packages/collab-web/dist" "$ROOT/public"

echo "sync-collab-web: validating Worker"
(
	cd "$ROOT"
	npm test
	npx tsc --noEmit
	npx wrangler deploy --dry-run
)

echo "sync-collab-web: done"

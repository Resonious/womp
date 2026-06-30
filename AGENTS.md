# Cloudflare Workers

STOP. Your knowledge of Cloudflare Workers APIs and limits may be outdated. Always retrieve current documentation before any Workers, KV, R2, D1, Durable Objects, Queues, Vectorize, AI, or Agents SDK task.

## Docs

- https://developers.cloudflare.com/workers/
- MCP: `https://docs.mcp.cloudflare.com/mcp`

For all limits and quotas, retrieve from the product's `/platform/limits/` page. eg. `/workers/platform/limits`

## Commands

| Command | Purpose |
|---------|---------|
| `npx wrangler dev` | Local development |
| `npx wrangler deploy` | Deploy to Cloudflare |
| `npx wrangler types` | Generate TypeScript types |
| `npm run sync:frontend` | Refresh `public/` from the latest omp collab web build, applying this repo's self-host patch |

Run `wrangler types` after changing bindings in wrangler.jsonc.

## Collab Frontend Assets

`public/` is generated from omp's `packages/collab-web` build. Do not hand-edit
files in `public/`; refresh them with:

```bash
npm run sync:frontend
```

By default, the sync script fetches `OMP_REF=main` from
`https://github.com/can1357/oh-my-pi.git` into `.cache/`, applies
`patches/omp-collab-web-current-origin.patch` if upstream does not already
include it, builds `packages/collab-web`, replaces `public/`, and validates the
Worker.

Useful overrides:

```bash
OMP_REF=<commit-or-branch> npm run sync:frontend
OMP_SOURCE=/path/to/oh-my-pi npm run sync:frontend
OMP_REPO=https://github.com/can1357/oh-my-pi.git npm run sync:frontend
```

The patch makes bare browser links (`room.key`) resolve against the current web
origin, so a self-hosted frontend at `https://omp.snd.one` connects to
`wss://omp.snd.one` instead of the upstream default `wss://my.omp.sh`.

The sync command runs:

- omp collab-web link parser tests
- a bare-link hosted-origin smoke check
- collab-web build
- this Worker's `npm test`
- `npx tsc --noEmit`
- `npx wrangler deploy --dry-run`

## Inspecting omp Protocol Changes

When updating the frontend or relay behavior, manually inspect the current omp
source before changing this Worker. The important files are:

```text
packages/collab-web/scripts/local-relay.ts
packages/collab-web/src/lib/link.ts
packages/collab-web/src/lib/socket.ts
packages/collab-web/src/lib/client.ts
packages/coding-agent/src/collab/protocol.ts
packages/coding-agent/src/collab/host.ts
packages/wire/src/index.ts
packages/collab-web/test/local-relay.test.ts
packages/collab-web/test/link.test.ts
```

Checklist:

- Compare the relay contract in `local-relay.ts` with this Worker's
  `CollabRelayRoom`: route shape, roles, close codes/reasons, text control
  messages, host/guest lifecycle, peer ID assignment, and binary forwarding.
- Compare envelope constants and helpers: 4-byte big-endian peer ID,
  broadcast peer `0`, guest peer rewrite, and key/token byte lengths.
- Check `socket.ts` for client expectations around reconnects, fatal close
  codes, binary frame shape, and text control frames.
- Check `protocol.ts` and `link.ts` for link formatting/parsing changes,
  default relay/web URLs, compact link behavior, and write-token handling.
- Check `packages/wire/src/index.ts` for `COLLAB_PROTO`, `DEFAULT_RELAY_URL`,
  constants, and wire frame/control type changes.
- Run the upstream baseline when possible:

```bash
bun install
bun --cwd=packages/collab-web test test/local-relay.test.ts test/link.test.ts
```

Then run this repo's validation:

```bash
npm run sync:frontend
npm test
npx tsc --noEmit
npx wrangler deploy --dry-run
```

## Node.js Compatibility

https://developers.cloudflare.com/workers/runtime-apis/nodejs/

## Errors

- **Error 1102** (CPU/Memory exceeded): Retrieve limits from `/workers/platform/limits/`
- **All errors**: https://developers.cloudflare.com/workers/observability/errors/

## Product Docs

Retrieve API references and limits from:
`/kv/` · `/r2/` · `/d1/` · `/durable-objects/` · `/queues/` · `/vectorize/` · `/workers-ai/` · `/agents/`

# Samartha Tower

A personal operating system, built to fix one root problem: **the future doesn't feel real, so the present always wins.**
Every level makes Future You a little more concrete.

| Level | Name | Trait |
|---|---|---|
| 00 | Reactor | Core dashboard, letters across time, future projection |
| 01 | Negotiator | Plan the day as a deal between Present You and Future You |
| 02 | Truth Chamber | Private, locked honesty journal |
| 03 | The Lab | Random topics, collisions, a map of your mind |
| 04 | The Forge | Keystone habits, identity votes, weekly self-breakdown |
| ∞ | Vault | Backup / restore, settings |

Local-first: all data lives in your browser's IndexedDB. No server, no account, no AI.

## Run

```bash
npm install
npm run dev      # http://localhost:5173
npm run build    # production build in dist/
```

## Structure

- `src/db/` — shared data model (`types.ts`) and Dexie database (`db.ts`)
- `src/lib/` — date helpers and the level registry
- `src/components/` — shared UI (nav, level header)
- `src/levels/<level>/` — each level is self-contained
- `src/index.css` — the HUD theme and shared utility classes

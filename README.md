# The Attic

A place to climb up into and open boxes you've never opened. The Attic is built for one thing:
**overcharging openness to experience**, the personality trait behind curiosity, imagination and the
appetite for the new.

It feeds all six facets of openness:

| Facet | What it means | Fed by |
|---|---|---|
| Ideas | Intellectual hunger | Science, Mathematics, Philosophy, Technology, Economics & Game Theory, Language, Cosmos & Space, The Body & Medicine |
| Imagination | Daydreams, stories, what-ifs | Literature, Religion & Myth, Futures & Speculation, Strange but True, Games & Play |
| Beauty | Being moved by art and form | Art, Architecture & Design, Cinema & Film, Crafts & Making |
| Feelings | Noticing your inner weather | Psychology, Music, Emotions & Inner Life |
| Adventure | New places, foods, experiences | Nature & Biology, Food & Cuisine, Places & Geography |
| Values | Re-examining beliefs and customs | History, Culture & Anthropology, Ethics & Dilemmas |

## Rooms

- **Spin**: draw one, two or three topics from about 2,000 hand-written ones across 26 categories. Lock one
  and re-spin the others, feed a single facet, or turn on **Stretch**, which favours categories you
  have explored least. Every draw comes with something to think about.
- **Dares**: 90 real-world challenges, 15 per facet, plus a dare of the day. Save them for later, then
  log what you noticed when you've done them.
- **Fuel**: your openness gauge for the last 30 days, broken down by facet. It names the facet that is
  running low, lists the categories you've never opened, and lets you back up or import your data.
- **Log** and **Map**: everything you've explored, and the mind map it grows into.

Local-first: all data lives in your browser's IndexedDB. No server, no account, no AI.
Lab entries from Samartha Tower carry over automatically (same database).

## Run

```bash
npm install
npm run dev      # http://localhost:5173
npm run build    # production build in dist/
```

## Structure

- `src/attic/` holds the whole app: topics (`topics*.ts`), facets and dares (`facets.ts`), fuel maths
  (`fuel.ts`) and one file per tab
- `src/db/` holds the data model (`types.ts`) and the Dexie database (`db.ts`)
- `src/lib/` holds date helpers and service-worker registration
- `scripts/gen-icons.mjs` re-renders the PNG icons from `public/icon.svg`

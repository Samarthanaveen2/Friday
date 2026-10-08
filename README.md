# Friday

**Every text box is a command line.** Instagram DMs, a Gmail draft, a Notion page, the ChatGPT box, a random search field: wherever your cursor already is, type a command after `;;` and press Enter. Friday runs it, and the page never receives that Enter.

```
;;search keyboard layouts     → new tab: Google results
;;keyboard layouts            → same thing (search is the default)
;;yt lofi beats               → YouTube search
;;ask explain MV3 extensions  → Claude, prefilled      (;;gpt … for ChatGPT)
;;gh tauri                   → GitHub search
;;open github.com             → open a site            (;;open instagram works too)
;;go gmail                    → jump to your open Gmail tab (opens it if there isn't one)
;;note call mom at 6          → saved in Friday's popup
```

When a command runs, Friday removes it from the field, so your half-written email or DM stays as it was.

## Install (Chrome / Edge / Brave / Arc)

1. `chrome://extensions` → turn on **Developer mode**
2. **Load unpacked** → pick the `extension/` folder
3. Type `;;search hello` in any text box and press Enter

Click the toolbar icon to change the prefix, see the cheat sheet, or read your notes.

## How it works

- `extension/content.js` runs in every frame. It listens for Enter in the capture phase, before the page's own handlers (so Gmail doesn't send and Instagram doesn't post). It looks only at the text before the caret on the current line. If the text has no prefix, it does nothing and nothing leaves the page.
- It works with `<input>`, `<textarea>` and rich `contenteditable` editors (Gmail, ChatGPT, Notion, Slack, Instagram DMs). For rich editors it deletes the command through `execCommand`, so the editor's own state stays in sync.
- `extension/commands.js` turns the text into an action (pure functions, unit-tested). `extension/background.js` runs the action with `chrome.tabs` / `chrome.storage`.
- Password fields are never read, and only `http(s)` URLs are ever opened.

## Limits

- Chrome won't run extensions on `chrome://` pages, the Chrome Web Store, or the address bar.
- Some sites put their editor inside a cross-origin iframe or a closed shadow root. Friday may not see those fields.
- For now it only works in the browser. Making this OS-wide (Notes.app, VS Code, Slack desktop) needs a native helper that watches keystrokes, like how Espanso or Raycast work.

## Ideas for next

- `;;write <instructions>`: send the command plus the surrounding text to Claude and **replace it in place** with the answer (draft a reply right inside Gmail or Instagram).
- `;;summarize`: summarize the page you're on.
- Custom user commands (`;;jira 123` → your Jira URL).

## Development

```
npm test   # unit tests for the command parser
```

## Clear Desk (`dashboard/`)

Your day as a white desk seen from above, lit by the real time of day. The desk has five spots for notes, and **you can only write a new note when a spot is free**.

- **Notes**: tap a free spot or the sticky pad; a sheet peels off, flies into place, and the pen follows your handwriting. Finish a note and it gets crossed out, crumpled and thrown into the wire bin. Drag notes to the bin, to the drawer, or onto each other to swap them. Everything can be undone.
- **Light**: cool morning light through the blinds, warm golden hour, a lamp at night. Shadows lean with the sun, and leaf shadows drift across the desk.
- **Letter tray**: bills due within a week arrive as envelopes; mark one paid and it gets stamped and filed.
- **Phone**: today's Google Calendar on the lock screen, a day timeline on tap, and a Dynamic Island for focus and "up next".
- **AirPods case**: opens a 25 minute focus session with brown noise; everything but the notes dims.
- **Legal pad**: Claude writes a plan for the rest of the day while the pen moves along. **Index card**: habits with tally-mark streaks. **Notebook**: the weekly review, signed off by hand. **Mug**: the coffee level is how much of today is left. **Tear-off calendar**: yesterday's page tears away each morning.
- **Drawer**: everything not for today, as index cards. Capture with `#money`, `!fri`, `!tomorrow`, `!+3`, or paste a brain dump for Claude to sort. Press `n` anywhere to write a note.

Open `dashboard/index.html` in a browser to use it locally (saved in that browser), or use the claude.ai version, which saves to your account and connects Google Calendar and Claude. Sounds are synthesised in the page; the speaker button mutes them.

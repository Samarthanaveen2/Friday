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

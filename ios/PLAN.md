# Friday for iPhone — build plan

This is the full spec for the Friday iOS app. It is written for whoever builds it (a Claude Code session or a person) and is the single source of truth. Build the whole thing; there is no v1/v2.

Owner's device: **iPhone 16 Pro, iOS 26**. No paid Apple Developer account and no usable Mac. Installed by sideloading (SideStore, free Apple ID, re-signed every 7 days).

---

## 1. What the app is

You talk; it gets done. Two jobs:

1. **Dictation like Wispr Flow, in any app.** A custom keyboard. In WhatsApp, Instagram, Notes, anywhere: tap mic, talk, tap ✓, clean text appears in the box within ~1 s.
2. **A day list you run by voice.** Say what's on your plate, what you finished, what moves. The Today screen updates. You name the priorities; the app never decides them.

Tone: high agency, very low noise. No assistant voice ("Sure! I've added…"), no history screens, no stats, no chat UI.

---

## 2. Features (all ship)

### 2.1 Today screen (the only real screen)
- Header: date (small caps, grey), large title **Today**.
- **Focus**: only items the user named as today's priority. Big rows (18 pt semibold) in a white card. Max 3 open items is a guideline shown visually; the app does not enforce or auto-demote.
- **Also**: everything else. Small grey rows (15 pt), no card.
- **Next**: one line, the next upcoming item after today (e.g. `Next: Project meeting · Sat 16:00`).
- Each row: tap-to-toggle checkbox (44 pt target), title, optional time on the right.
- If no Focus has been named today: Focus shows one quiet line, `Say what matters today.`
- Big mic button at the bottom center (76 pt circle, accent color).
- After any voice change: changed rows get a light accent tint + a small note (`New`, `Done`, `from 14:00`, `moved → Sun`) for ~5 s, and a dark pill `N changes · Undo` above the mic.
- Long-press a row: Edit title/time, Move to tomorrow, Delete. (Manual fallback; voice is primary.)
- A small gear in the top-right opens Settings (sheet).

### 2.2 Talking state
- Bottom sheet slides up over the dimmed Today list: waveform, **live transcript** in 20 pt, red stop button.
- Stop (or Action button again) → transcript goes to the command brain → Today updates → sheet closes.

### 2.3 Priority rules (user decides, app never guesses)
- The user says priorities explicitly, anywhere in the utterance or in a later one: "priority today is the warden and the group reply", "make gym top priority", "laundry isn't important".
- Named items → Focus (for today only). Everything else → Also.
- **Rollover** (runs on first app/keyboard activity each new day; also when the app foregrounds):
  - Unfinished items from past days move to today, keeping their time of day.
  - Rolled-over items always land in **Also** (Focus is reset daily; it only holds what the user named today).
- Items with a future date ("Sunday", "tomorrow at 10") stay on that date and appear in Today when the day comes.

### 2.4 Friday keyboard (Wispr Flow clone)
- Custom keyboard extension, works in any app that allows third-party keyboards.
- Buttons: **🎤 mic** (start/stop), **✓** (stop + insert), **→ Friday** (stop + send to the day list instead of inserting), **globe** (next keyboard), **delete**, **return**, **space**. A full QWERTY is NOT needed; keep it a compact voice bar + minimal keys.
- Flow:
  1. First mic tap in a session: the keyboard opens the main app (URL scheme `friday://session`), the app starts the audio session, and returns the user (on iOS 26.4+ the user may need to swipe back — same as Wispr Flow; show a one-line hint the first time).
  2. Session stays alive until idle for N minutes (setting: 5 / 15 / 60 / never; default 15). While alive, mic taps start recording instantly with no bounce.
  3. ✓ → final cleaned text is inserted with `textDocumentProxy.insertText`.
  4. → Friday → text is handed to the command brain; the keyboard shows a tiny confirmation like `3 changes` with Undo.
- The keyboard may read `documentContextBeforeInput` (the text already in the box) and send it as context so dictation continues the sentence correctly. It cannot read the chat history.
- Falls back to the system keyboard in password / number / phone fields (iOS does this automatically).

### 2.5 Action button / Siri, from anywhere
- App Intent `TalkToFriday` (an `AudioRecordingIntent`, iOS 18+) so recording starts **without opening the app**, with a **Live Activity** (lock screen + Dynamic Island) showing it's listening. Press again (or tap stop in the Live Activity) → command brain → done.
- Second intent `DictateToClipboard` (optional): records, cleans, copies to clipboard.
- User maps the Action button: Settings › Action Button › Shortcut › "Talk to Friday". Also works via "Hey Siri, talk to Friday".

### 2.6 Calendar & Reminders mirror
- Friday's own store is the source of truth.
- Timed items are mirrored to a calendar named **Friday** (EventKit); untimed items to a Reminders list named **Friday**. Completing/moving in Friday updates the mirror. One-way (Friday → Apple) to keep it simple and reliable.
- Read the user's other calendars to show fixed events (lectures, meetings) in Today as Also rows with a calendar dot, read-only.

### 2.7 Notifications
- Local notifications only (no server push — impossible with free signing).
- Only for **Focus items with a time**: 10 min before. Nothing else. No daily summaries.

### 2.8 Settings (sheet, rarely opened)
- Groq API key (stored in Keychain, shared with the keyboard via the keychain access group / App Group).
- AI mode: `Cloud (Groq) + on-device backup` (default) / `On-device only`.
- Session timeout for the keyboard.
- Accent color (4 swatches).
- Permissions status rows (Mic, Speech, Calendar, Reminders, Notifications) with "Fix" buttons.
- "Set up the Friday keyboard" and "Set up the Action button" — each opens a short how-to.
- Export (JSON of all items to Files).

---

## 3. AI pipeline (free + fast)

Decision: **cloud first for quality and speed, on-device as automatic backup.** The owner explicitly does not mind audio going to the cloud. English only.

| Step | Primary | Backup |
|---|---|---|
| Live words while talking | **Apple SpeechAnalyzer / SpeechTranscriber** (on-device, streaming, iOS 26) | — |
| Final transcript | **Groq `whisper-large-v3-turbo`** | SpeechAnalyzer final result |
| Dictation cleanup | **Groq small fast LLM** (`llama-3.1-8b-instant` or the fastest current free model) | Apple Foundation Models (on-device ~3B) |
| Day-list commands | **Groq larger LLM** (`llama-3.3-70b-versatile` / `openai/gpt-oss-120b`, whichever is on the free tier) with JSON output | Apple Foundation Models with `@Generable` structured output |

Check current model IDs and free limits at console.groq.com before hard-coding; keep model IDs in one config file.

### 3.1 How it's fast (the Wispr trick)
1. Record 16 kHz mono. Run SpeechAnalyzer live the whole time (instant preview + guaranteed fallback).
2. **Chunk on pauses**: when VAD sees ≥600 ms of silence and the chunk is ≥4 s, upload that chunk to Groq Whisper immediately, in the background, while the user keeps talking. Keep ≤ ~15 requests/min (free tier is ~20 RPM for audio).
3. On ✓: upload only the final chunk; stitch chunk transcripts in order.
4. Cleanup/command LLM call with a short prompt, `stream: false`, small `max_tokens`.
5. **Race**: if the cloud result isn't back within **1.2 s** of ✓, use the on-device transcript + on-device model instead. Never make the user wait on the network.
6. Keep one warm `URLSession` with HTTP/2 keep-alive; send a tiny request when a session starts to pre-warm TLS.

Target: ✓ → text inserted in **0.5–1 s** on a normal connection. Log timings (debug overlay in Settings) so they can be tuned on the device.

### 3.2 Free-tier reality
Third-party listings (verify in the Groq console): Whisper ~2,000 requests/day, ~8 h audio/day, ~20 RPM; small LLM ~14,400 requests/day. Owner's use is tiny vs that. If a 429 is returned, silently use the on-device path. Paid would be < $1/month anyway (Whisper turbo $0.04/hour of audio).

### 3.3 Dictation cleanup prompt (system)
```
You clean up dictated text. Output ONLY the final text, nothing else.
- Remove filler words (um, uh, like, you know) and false starts.
- Apply spoken self-corrections ("at 5, no wait, 6" -> "at 6").
- Fix punctuation, capitalization, and obvious mis-hearings.
- Keep the speaker's words, tone, and slang. Do not add, summarize, or make it formal.
- Spoken formatting: "new line", "new paragraph", "question mark", "bullet" -> apply them.
- If CONTEXT is given, continue naturally from it (e.g. no capital if mid-sentence).
```
User message: `CONTEXT: <text before cursor, last 300 chars or empty>\nDICTATION: <transcript>`.

### 3.4 Command brain
The model never edits data directly. It returns a list of operations; the app validates and applies them, so Undo is exact.

Input to the model:
```
NOW: 2026-10-08T08:14 Thursday (Asia/Kolkata)
ITEMS (today and future, open + done today):
[{"id":"a1","title":"Finish lab report","date":"2026-10-08","time":"11:30","focus":true,"done":false}, ...]
SAID: "<transcript>"
```
System prompt:
```
You turn what the user said into operations on their day list. Output JSON only:
{"ops":[ ... ]}
Operations:
 {"op":"add","title":str,"date":"YYYY-MM-DD","time":"HH:MM"|null,"focus":bool}
 {"op":"complete","id":str}
 {"op":"uncomplete","id":str}
 {"op":"move","id":str,"date":"YYYY-MM-DD","time":"HH:MM"|null}
 {"op":"rename","id":str,"title":str}
 {"op":"delete","id":str}
 {"op":"setFocus","id":str,"focus":bool}
Rules:
- Match existing items by meaning ("the report" = "Finish lab report"). Use their id. Never invent ids.
- focus=true ONLY when the user explicitly calls it a priority / important / top / focus. Otherwise false.
  "Priority today is X and Y" -> setFocus true for X and Y (add them if they don't exist).
- Resolve relative dates/times from NOW ("tomorrow", "Sunday", "at 5" -> 17:00 if it's daytime context).
- Titles: short, verb-first when natural, no dates/times inside the title.
- If nothing actionable was said, return {"ops":[]}.
```
Use Groq JSON mode (`response_format: {"type":"json_object"}`). Validate: unknown id → drop op; bad date → drop op. Apply all valid ops in one transaction, push one undo entry.

On-device backup: same schema via Foundation Models `@Generable struct Ops`.

---

## 4. Architecture

```
Friday (main app, SwiftUI)
 ├─ AudioEngine        AVAudioEngine capture, VAD chunking, keeps session alive in background (UIBackgroundModes: audio)
 ├─ Transcriber        SpeechAnalyzer live + Groq Whisper chunks + race
 ├─ Brain              cleanup + command calls (Groq, Foundation Models fallback)
 ├─ Store              items (SwiftData or a JSON file in the App Group container), undo stack, rollover
 ├─ Mirror             EventKit calendar + reminders sync
 ├─ Notifier           local notifications for timed Focus items
 └─ Intents            AudioRecordingIntent + Live Activity, App Shortcuts
FridayKeyboard (keyboard extension, UIKit/SwiftUI, RequestsOpenAccess = YES)
 └─ talks to the app through the App Group (shared file + Darwin notifications)
FridayLive (widget extension) — Live Activity UI only
FridayCore (Swift package, NO Apple UI frameworks) — models, ops, validation, apply, undo, rollover, date logic
 └─ unit-tested on Linux with `swift test`
```

- **Keyboard ↔ app IPC**: App Group `group.<bundle-prefix>.friday`. Keyboard writes a request (`start`, `stop+insert`, `stop+friday`, `cancel`) to a small file and posts a Darwin notification (`CFNotificationCenterGetDarwinNotifyCenter`); the app does the work and writes the result back + posts a notification; keyboard inserts. Keyboards have ~50–70 MB memory: no models, no audio in the extension.
- **Storage**: a single JSON file in the App Group container is fine (tiny data, easy for both processes, easy export). Use file coordination.
- **Bundle IDs** (sideloading rewrites them, keep them stable): `com.samarth.friday`, `com.samarth.friday.keyboard`, `com.samarth.friday.live`. Changing them = new app = data lost.
- **Deployment target**: iOS 26.0 (needed for SpeechAnalyzer + Foundation Models).

---

## 5. Build & install without a Mac

1. **Project generation**: XcodeGen `ios/project.yml` (checked in). Never hand-edit a `.xcodeproj`.
2. **CI** `.github/workflows/ios.yml` on `macos-26` (or the newest runner with Xcode 26):
   - `brew install xcodegen && xcodegen generate`
   - `xcodebuild -scheme Friday -sdk iphoneos -configuration Release CODE_SIGNING_ALLOWED=NO CODE_SIGNING_REQUIRED=NO build`
   - Package `Payload/Friday.app` (with its `PlugIns/` extensions) into `Friday.ipa`.
   - Upload as a workflow artifact and publish to a GitHub Release tagged `latest` (so the phone can download it directly).
   - Also run `swift test` for FridayCore.
   - Repo is **public**, so macOS minutes are free.
3. **Install**: on the iPhone, download `Friday.ipa` from the Release → share to SideStore → install. SideStore re-signs with the free Apple ID; extensions and App Group IDs are rewritten automatically.
4. **Refresh** in SideStore every 7 days (or let its background refresh do it). Data survives refreshes; never delete the app.

Free Apple ID limits: 3 active sideloaded apps, 10 App IDs per 7 days. Friday uses 3 App IDs (app + keyboard + widget). Fine.

---

## 6. Build order (all of it ships; this is just the order)

1. **Install probe**: minimal app + empty keyboard + empty widget + App Group + background audio mode. CI builds it; owner installs via SideStore. Confirms extensions + App Group survive free signing. Do not build further until this works.
2. FridayCore package with tests: models, ops, validate/apply, undo, rollover, date resolution.
3. Today UI (matches `ios/design/`), store, long-press edit, Settings sheet.
4. AudioEngine + SpeechAnalyzer live transcript + Talking sheet.
5. Groq client (Whisper chunks, LLM), race + fallback, Foundation Models backup, timing overlay.
6. Command brain end-to-end, change highlights, Undo pill.
7. Keyboard extension + IPC + session logic + insert.
8. AudioRecordingIntent + Live Activity + App Shortcuts (Action button).
9. EventKit mirror, read-only calendar events, notifications.
10. Tune on device: latency, VAD thresholds, prompts with the owner's real speech.

---

## 7. What iOS lets it do — the real limits

Even with every permission granted, iOS sandboxes apps. Knowing the line:

**Can do**
- Dictate into any text box via its keyboard; read the text already in that box.
- Calendar, Reminders, Contacts, Location, Health, Photos (with permission).
- Local notifications, alarms/timers (AlarmKit, iOS 26), Live Activities, Action button, Siri/Shortcuts.
- Prepare a message and open it ready to send: `whatsapp://send?phone=…&text=…`, SMS/iMessage compose sheet, mail compose, `tel:` to call. One tap from you sends it.
- Run your Shortcuts (`shortcuts://run-shortcut?name=…`), which can chain many system actions.
- Anything with a web API: Gmail, Google Calendar, Notion, Spotify, web search (needs sign-in / keys).
- Take a shared screenshot/image/text from the Share sheet and turn it into items (OCR via Vision).

**Cannot do**
- Read WhatsApp/Instagram/iMessage chats, notifications from other apps, or what's on screen.
- Send a WhatsApp/iMessage by itself (always one tap from you).
- Tap buttons or control other apps.
- Always-on "Hey Friday" wake word when no session is running (while a session is live, the mic is on, with the orange dot).
- Server push notifications, iCloud sync (need a paid developer account).
- Work in password fields or apps that block third-party keyboards (some banking apps).

---

## 8. Known risks
- Keyboard → app bounce on session start can require a manual swipe back on iOS 26.4+ (Wispr Flow has the same issue). The Action button path doesn't need it.
- Groq free limits/model IDs can change → config file + automatic on-device fallback.
- Background audio session costs some battery while a keyboard session is live; the idle timeout limits it.

---

## 9. Design reference
`ios/design/` has the agreed mockups (HTML artboards, 390×844):
- `Main.dc.html` — Today (Focus / Also / Next / mic)
- `Listening.dc.html` — Talking sheet
- `Updated.dc.html` — Today after a command, with highlights + Undo pill

Look: stock iOS. Background `#F2F2F7`, cards `#FFFFFF` radius 16, separators `#E3E3E8`, text `#111114`, secondary `#5F5F66`, accent `#4338CA` (indigo), change tint `#EEF0FF`, stop red `#D92D20`. SF system font. Use native SwiftUI (List/sections styled to match), not a web port.

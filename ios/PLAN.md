# Friday for iPhone — the plan

The full spec for the Friday iOS app and the single source of truth. Build all of it; there is no v1/v2. Section 13 is the build order.

- **Device:** iPhone 16 Pro, iOS 26. English only.
- **Constraints:** no paid Apple Developer account, no usable Mac. Built by GitHub Actions, installed with SideStore on a free Apple ID (re-signed every 7 days).
- **Priorities:** fast, free, gets it done. Privacy is not a goal: cloud is fine.
- **Style:** high agency, very low noise. No assistant voice ("Sure! I've…"), no history screens, no stats, no chat UI. Short, plain text everywhere.

---

## 1. What Friday is

You talk, it gets done. Three entry points, one brain:

| Entry | What you do | What happens |
|---|---|---|
| **Friday keyboard** (in any app) | 🎤 → talk → ✓ | Clean text typed into the box (Wispr Flow clone) |
| | 🎤 → talk → **→ Friday** | Treated as a command (day list, message, alarm, …) |
| | ✨ → "make it shorter" | Rewrites the text already in the box |
| **Action button / Siri** (anywhere, no app open) | press → talk → press | Command |
| **Friday app** (Today screen) | mic → talk → stop | Command |

---

## 2. The Today screen (the only real screen)

Matches `ios/design/`. Native SwiftUI, styled like stock iOS.

- **Header:** date in small grey caps, large title **Today**, small gear (Settings) top-right.
- **Focus:** only items you named as priority today. Big rows (18 pt semibold) in a white card.
  - If you haven't named any today: one quiet line, `Say what matters today.`
- **Also:** everything else. Small grey rows (15 pt), no card. Includes read-only events from your other calendars (lectures, Google Calendar) with a small calendar dot.
- **Next:** one line for the next thing after today: `Next: Project meeting · Sat 16:00`.
- **Rows:** 44 pt checkbox (tap toggles), title, time on the right, small 📍 if it's location-triggered. Long-press: Edit, Move to tomorrow, Delete.
- **Mic:** 76 pt accent circle at the bottom centre.
- **After a command:** changed rows get a light tint and a short note (`New`, `Done`, `from 14:00`, `→ Sun`) for ~5 s. A dark pill `N changes · Undo` appears above the mic.
- **Result card** (for non-list results), above the mic, dismissible, one at a time:
  - **Answer:** 1–3 lines of text (e.g. "Arsenal play Chelsea Sat 22:00 IST").
  - **Action:** a short preview plus one button: `Send on WhatsApp`, `Send email`, `Call Rahul`, `Open`. A second, smaller button: `Edit`.
  - **Choice:** when a name is ambiguous ("Rahul S" / "Rahul K"): 2–3 buttons.

### Talking state
A bottom sheet over the dimmed list shows a waveform, the **live transcript** (20 pt) and a red stop button. On stop the sheet closes and changes land.

---

## 3. Priority and rollover rules (you decide, the app never guesses)

- You say priorities explicitly, in the same breath or later: "priority today is the warden and the group reply", "make gym top priority", "laundry isn't important".
- Named items → **Focus** (today only). Everything else → **Also**.
- **Rollover** runs on the first activity of a new day (app open, keyboard use, Action button) and on every foreground:
  - unfinished items from past days move to today, keeping their time of day;
  - rolled-over items always land in **Also**. Focus resets daily.
- Future-dated items ("Sunday", "tomorrow 10") wait for their day.

---

## 4. The Friday keyboard (Wispr Flow clone)

A compact voice bar with minimal keys. Not a full QWERTY.

```
[ 🌐 ]  [ ✨ ]   ( 🎤 big )   [ → Friday ]  [ ⌫ ]
[         space          ]  [ return ]
```

- **🎤** starts and stops recording. While recording, the live transcript shows in a strip above the keys and 🎤 becomes **✓**.
- **✓**: stop, clean up, insert with `textDocumentProxy.insertText`.
- **→ Friday**: stop, send to the command brain. The strip shows `3 changes · Undo` or the result card's one-liner. Action buttons (e.g. `Send on WhatsApp`) appear in the strip.
- **✨ Command mode**: talk an instruction ("make it shorter", "more polite", "fix grammar", "turn into bullet points"). Friday reads the text in the box (`documentContextBeforeInput` + `documentContextAfterInput`), rewrites it, deletes the old text and inserts the new. iOS only exposes text near the cursor (roughly the current paragraph or a few hundred characters), so this works on messages and short drafts, not long documents.
- **Context:** for ✓ the text already before the cursor is sent as context, so dictation continues mid-sentence correctly (no stray capital or duplicated words).
- **Session (same as Wispr Flow):**
  1. The first 🎤 of a session opens the main app (`friday://session`) through the responder-chain `openURL` trick keyboards use. The app starts the audio session and returns. On iOS 26.4+ the user may have to swipe back. Show a one-line hint the first time.
  2. The session stays alive until idle for N minutes (5 / 15 / 60 / never, default 15). While it's alive, 🎤 starts instantly with no bounce.
  3. While a session is live the orange mic dot is on. That's expected.
- iOS switches to the system keyboard by itself for password, phone and number fields.

---

## 5. Everything Friday can do (the command brain's abilities)

All of these come from one spoken command, in the app, through **→ Friday**, or from the Action button.

| Ability | Example | How |
|---|---|---|
| **Day list** | "done with the report, gym to 5, laundry Sunday, priority is warden" | Own store, mirrored to Calendar/Reminders |
| **Calendar** | "lunch with Ana Friday 1pm" | EventKit. Timed items mirror to a **Friday** calendar. Reads all calendars, Google included if the account is added in iOS Settings |
| **Reminders** | (untimed items) | EventKit, a **Friday** Reminders list |
| **Messages: WhatsApp** | "tell Rahul I'll be 10 min late" | Contact lookup → `whatsapp://send?phone=…&text=…`. Opens ready to send, you tap Send |
| **Messages: SMS/iMessage** | "text mom I reached" | `MFMessageComposeViewController` (or `sms:` with body). You tap Send |
| **Email (Gmail)** | "email the professor asking for an extension" | Draft shown in the result card → `Send email` sends through the Gmail bridge (§7). Or "summarise my unread emails" → answer card |
| **Calls** | "call warden" | `tel:`. iOS asks once, you tap Call |
| **Alarms & timers** | "wake me at 6:30", "timer 20 min" | AlarmKit (iOS 26). Fallback: Shortcuts bridge |
| **Location reminders** | "remind me to buy milk when I reach the market" | Apple Maps search near you (`MKLocalSearch`) + `CLMonitor` geofence → local notification. Saved places: "this is my hostel" saves the current location |
| **Contacts** | "what's Rahul's number", and names for messages/calls | `CNContactStore`, fuzzy match locally, choice card if ambiguous |
| **Health** | "how many steps today", "how did I sleep" | HealthKit read (if free signing allows it, see §13 step 1). Fallback: Shortcuts bridge |
| **Music** | "play lofi on Spotify", "play my gym playlist" | Spotify Web API (PKCE login; playback control needs Premium) or a `spotify:` deep link. Apple Music library via `MPMusicPlayerController` |
| **Notion** | "add this idea to my Notion" | Notion API with an internal integration token. Appends to a chosen page or database |
| **Web questions** | "when's the next Arsenal match, add it" | Gemini with Google Search grounding; Tavily search as backup (§6) |
| **Screenshots / photos → items** | Share a screenshot of a notice → "add these" | Share extension + Vision OCR (on-device) → command brain |
| **Your Shortcuts** | "run my study-mode shortcut" | `shortcuts://run-shortcut?name=…&input=…` |
| **Open apps / places** | "open Instagram", "directions to the station" | URL schemes, Apple Maps directions URL |
| **Dictation extras** | (keyboard) | Personal dictionary and snippets (§8) |

**One-tap rule:** iOS never lets an app send a WhatsApp/iMessage or place a call by itself. Friday prepares it and you tap once. Email through the Gmail bridge *can* send without opening anything, but still needs the one tap on `Send email` (no voice-only sends, to avoid mistakes).

---

## 6. AI stack (free + fast) — final choices

Every network provider is behind one **OpenAI-compatible client**, with model IDs in one config file (`ios/Friday/Config/Models.swift`). Swapping a provider is a config change.

| Job | Primary | Backup 1 | Backup 2 |
|---|---|---|---|
| Live words while talking | **Apple SpeechAnalyzer / SpeechTranscriber** (on-device, streaming) | — | — |
| Final transcript | **Groq `whisper-large-v3-turbo`** | SpeechAnalyzer final result | — |
| Dictation cleanup (✓) | **Groq `openai/gpt-oss-20b`** (`reasoning_effort: low`) | Gemini Flash-Lite | Apple Foundation Models |
| Rewrite (✨) | **Groq `openai/gpt-oss-20b`** | Gemini Flash-Lite | Apple Foundation Models |
| Command brain | **Groq `openai/gpt-oss-120b`** (`reasoning_effort: low`, JSON output) | Gemini Flash | Apple Foundation Models (`@Generable`, day-list ops only) |
| Web answers | **Gemini Flash + Google Search grounding** | Tavily search → Groq 120b summarises | "Can't search right now" |
| OCR | **Apple Vision** (on-device) | — | — |

Why these:
- **Groq** runs these models at hundreds to 1,000+ tokens/s, which is what makes it feel instant. It's free with a key, no card. `llama-3.1-8b-instant` is reportedly being retired from the free tier, so use `gpt-oss-20b` for the fast path. Check `console.groq.com/docs/models` before hard-coding.
- **gpt-oss models are reasoning models:** always send `reasoning_effort: "low"` and a small `max_tokens`, or latency goes up.
- **Gemini** (Google AI Studio key, free, no card) is the overflow when Groq's daily free limit is hit, and the free way to get Google-grounded web answers.
- **Apple Foundation Models** is the offline and last-resort path, so Friday never fully stops working.
- **Apple SpeechAnalyzer** is accurate for English, streams in real time and costs nothing. Whisper is the "final" because it's better on names and accents.

### 6.1 Speed: the Wispr trick
1. Capture 16 kHz mono with `AVAudioEngine`. Feed SpeechAnalyzer live the whole time, for the instant preview and a guaranteed fallback.
2. **Chunk on pauses:** when VAD sees ≥600 ms silence and the chunk is ≥4 s, upload that chunk to Groq Whisper right away while you keep talking. Cap it at ~15 audio requests/min (the free tier is ~20 RPM).
3. On ✓, upload only the last chunk and stitch the chunk transcripts in order.
4. Pass Whisper a `prompt` with your dictionary words (§8) for names and terms.
5. Run cleanup/command with a short prompt, low reasoning and small `max_tokens`.
6. **Race:** if the cloud result isn't back **1.2 s** after ✓, use the on-device transcript plus the next backup model. Never wait on the network.
7. Keep one warm `URLSession` (HTTP/2 keep-alive). Send a tiny pre-warm request when a session starts.
8. **Quota tracker:** count requests and tokens per provider per day. Switch to the backup *before* hitting a limit, and on any 429/5xx.

**Target:** ✓ → text in the box in **0.5–1 s**. A debug timing overlay (toggle in Settings) shows each stage's ms so it can be tuned on the phone.

### 6.2 Free limits (verify in each console; they change)
Third-party listings put Groq Whisper at ~2,000 requests/day and ~8 h of audio/day. gpt-oss models have daily token caps (reportedly ~200K tokens/day) and Gemini Flash ~1,500 requests/day. Your use is far below that if prompts stay lean: the command prompt should be ≤1.5K tokens per call. Paid fallback would cost under $1/month, but isn't needed.

---

## 7. Integrations setup (all free)

| Service | What you set up once | Stored as |
|---|---|---|
| Groq | console.groq.com → API key | Settings → Keys |
| Gemini | aistudio.google.com → API key | Settings → Keys |
| Tavily | tavily.com → API key (1,000 searches/month free) | Settings → Keys |
| **Gmail bridge** | A Google Apps Script web app in *your* Google account (script in `ios/integrations/gmail-bridge.gs`): deploy as "Execute as me", paste its URL + a secret into Friday. Endpoints: `unread_summary`, `search`, `send`, `draft`. No OAuth tokens expiring weekly, nothing to pay | Settings → Gmail |
| Google Calendar | Add your Google account in iOS Settings → Calendar. Friday reads it through EventKit | — |
| Notion | notion.so/my-integrations → internal integration token, share the target page with it | Settings → Notion |
| Spotify | Spotify developer app (dev mode, free) → client ID. Friday logs in with PKCE | Settings → Spotify |

Keys live in the Keychain, shared with the keyboard via a keychain access group. If free signing rejects keychain sharing, use a file in the App Group container (`completeUntilFirstUserAuthentication` protection).

---

## 8. Dictation quality features
- **Personal dictionary:** words and names Friday should spell right (auto-seeded from your contacts' names plus words you add). Sent as Whisper's `prompt` and as SpeechAnalyzer contextual strings.
- **Snippets:** "my email" → `you@…`, "my address" → full address. Replaced deterministically *before* the LLM cleanup.
- **Spoken formatting:** "new line", "new paragraph", "question mark", "bullet point".
- **Self-corrections:** "at 5, no wait, 6" → "at 6".

---

## 8b. Personal memory (Friday learns the owner)

The models have no memory of their own. Friday keeps a small **memory file** (`memory.json` in the App Group) and sends the relevant parts with every request, so every model (Groq, Gemini, on-device) "knows" the owner. No retraining needed.

What it holds (kept compact, ≤ ~600 tokens when sent):
- **People:** "warden" → contact X; "the group" → WhatsApp group "Project 4"; "mom" → contact Y.
- **Places:** hostel, market, library (coordinates for location reminders).
- **Habits / defaults:** "gym" usually 17:00; "lab" means the Signals lab; lectures come from the calendar.
- **Words:** names and terms Friday mis-heard before, and how they're spelled (feeds the dictionary, §8).
- **Writing style:** how the owner writes messages (e.g. lowercase, short, "bro", no full stops) so cleanup and drafted messages sound like them, not like an assistant.
- **Facts:** anything said with "remember that…" ("remember my roll number is…").

How it learns (automatically, quietly):
1. **Voice:** "remember that…" / "forget that…" → add/remove an entry.
2. **Undo + re-say:** if a command is undone and re-said differently, store what the owner meant (e.g. "the group" was the Project 4 group).
3. **Edits after dictation:** after ✓ inserts text, the keyboard re-reads the box a few seconds later; if a word was changed (e.g. "Samartha" fixed from "Samantha"), add it to Words.
4. **Choice cards:** when the owner picks "Rahul K" over "Rahul S", remember that "Rahul" = Rahul K.
5. **Long-press edits** on items (renamed title, changed time) update Habits.

Rules: the memory is plain, viewable and editable in Settings ("What Friday knows"). The command brain may propose `{"a":"remember","key":s,"value":s}`; the app saves it without asking. Only send the entries relevant to the current request (match by words in the transcript) to keep prompts short and fast. Every learned miss is also appended to `ios/evals/` as a test case during tuning.

---

## 9. Prompts

### 9.1 Dictation cleanup (system)
```
You clean up dictated text. Output ONLY the final text.
- Remove filler words (um, uh, like, you know) and false starts.
- Apply spoken self-corrections ("at 5, no wait, 6" -> "at 6").
- Fix punctuation, capitalisation and obvious mis-hearings. Use DICTIONARY spellings.
- Keep the speaker's words, tone and slang. Do not add, summarise or make it formal.
- Apply spoken formatting: "new line", "new paragraph", "question mark", "bullet point".
- Continue naturally from CONTEXT (no capital mid-sentence, no repeated words).
```
User: `CONTEXT: <≤300 chars before cursor>\nDICTIONARY: <words>\nDICTATION: <transcript>`

### 9.2 Rewrite (✨, system)
```
Rewrite TEXT following INSTRUCTION. Output ONLY the rewritten text. Keep the language, meaning and the speaker's voice unless told otherwise.
```

### 9.3 Command brain (system, JSON mode)
Input:
```
NOW: 2026-10-08T08:14 Thu (Asia/Kolkata)
PLACES: ["hostel","market"]
MEMORY: {"people":{"warden":"Mr. Rao","the group":"WhatsApp: Project 4"},"habits":{"gym":"17:00"},"style":"lowercase, short, says bro"}
ITEMS: [{"id":"a1","t":"Finish lab report","d":"2026-10-08","tm":"11:30","f":true,"x":false}, ...]   // today + future + done today, compact keys
SAID: "<transcript>"
```
System:
```
Turn what the user said into actions. Output JSON only: {"actions":[...]}.
Day list:
 {"a":"add","title":s,"date":"YYYY-MM-DD","time":"HH:MM"|null,"focus":b,"place":s|null}
 {"a":"complete","id":s} {"a":"uncomplete","id":s} {"a":"delete","id":s}
 {"a":"move","id":s,"date":"YYYY-MM-DD","time":"HH:MM"|null}
 {"a":"rename","id":s,"title":s} {"a":"focus","id":s,"on":b}
Other:
 {"a":"message","app":"whatsapp"|"sms","to":s,"text":s}
 {"a":"email","to":s,"subject":s,"body":s}
 {"a":"call","to":s}
 {"a":"alarm","time":"HH:MM","date":"YYYY-MM-DD"|null,"label":s|null}
 {"a":"timer","minutes":n,"label":s|null}
 {"a":"save_place","name":s}
 {"a":"music","service":"spotify"|"apple","query":s}
 {"a":"notion","text":s}
 {"a":"shortcut","name":s,"input":s|null}
 {"a":"open","target":s}
 {"a":"ask","kind":"web"|"email"|"health"|"contacts","query":s}
 {"a":"remember","key":s,"value":s} {"a":"forget","key":s}
Rules:
- Match existing items by meaning ("the report" = "Finish lab report"); use their id; never invent ids.
- focus=true ONLY if the user explicitly calls it priority/important/top/focus. "Priority today is X and Y" -> focus on for X and Y (add them if missing).
- Resolve relative dates/times from NOW. Titles short, no dates/times inside them.
- Messages/emails: write the text the user would send, in their voice.
- Use "ask" only when an answer needs outside info.
- Nothing actionable -> {"actions":[]}.
```

**Execution:** the app validates every action (unknown id → drop, bad date → drop, unknown contact → choice card) and applies all day-list actions in one transaction with one undo entry. Each `ask` runs its fetch (web/Gmail/HealthKit/Contacts), then a **second** short call turns the fetched data into a 1–3 line answer and, if the user asked for it, follow-up actions ("add it" → `add`). All other abilities finish in **one** LLM round.

### 9.4 Prompt tests
`ios/evals/commands.jsonl`: 40+ real-style utterances with the expected actions. `ios/evals/run.sh` runs them against the configured provider with a local API key and prints pass/fail. Run it whenever a prompt or model changes.

---

## 10. Architecture

```
Friday (app, SwiftUI)
 ├─ Audio        AVAudioEngine capture, VAD chunking, background keep-alive (UIBackgroundModes: audio)
 ├─ Speech       SpeechAnalyzer live + Groq Whisper chunks + race
 ├─ AI           OpenAI-compatible client (Groq, Gemini), Foundation Models, quota tracker, prompts
 ├─ Brain        builds the command input, validates + executes actions, ask → fetch → answer
 ├─ Store        items JSON in the App Group container (file-coordinated), undo stack, rollover
 ├─ Mirror       EventKit calendar + reminders, read other calendars
 ├─ Abilities    Contacts, Messages, Mail(Gmail bridge), Calls, AlarmKit, Location(CLMonitor, MKLocalSearch),
 │               HealthKit, Music(Spotify/MPMusicPlayer), Notion, Web(Gemini/Tavily), Shortcuts, Open
 ├─ Notifier     local notifications: timed Focus items (10 min before), location triggers
 └─ Intents      TalkToFriday (AudioRecordingIntent + Live Activity), App Shortcuts for Siri/Action button
FridayKeyboard (keyboard extension, RequestsOpenAccess = YES)
 └─ voice bar UI; NO models, NO audio, NO network. Talks to the app over the App Group.
FridayLive (widget extension)   Live Activity UI (listening / thinking / done)
FridayShare (share extension)   receives images/text → OCR → hands to the app
FridayCore (Swift package, no UIKit/SwiftUI)
 └─ models, action schema, validation, apply, undo, rollover, date resolution, snippets — `swift test` on Linux + CI
```

- **Keyboard ↔ app:** App Group `group.com.samarth.friday`. The keyboard writes a request (`start`, `stop_insert`, `stop_command`, `rewrite`, `cancel`) to a small JSON file and posts a Darwin notification. The app does the work, writes the result and posts back, and the keyboard inserts/updates. Keyboards get ~50–70 MB, so all heavy work stays in the app.
- **Data model** (`FridayCore.Item`): `id, title, date, time?, focus, focusDate?, done, doneAt?, place?, ekID?, createdAt`. `focus` only counts when `focusDate == today`.
- **Bundle IDs (never change after the first install, or the data is lost):** `com.samarth.friday`, `.keyboard`, `.live`, `.share`.
- **Deployment target:** iOS 26.0. Swift 6, SwiftUI, Observation.

---

## 11. Settings and first run

**First run:** one checklist screen. Each row has a status and a Fix button:
- Microphone, Speech, Calendar, Reminders, Notifications, Contacts, Location (Always), Health.
- "Add the Friday keyboard" (opens Settings, plus 3-line instructions incl. Full Access).
- "Set up the Action button" (instructions).
- Keys: Groq (required), Gemini (recommended), Tavily, Gmail bridge, Notion, Spotify (optional).

**Settings sheet:**
- Keys and integrations
- AI mode: `Cloud + on-device backup` (default) / `On-device only`
- Keyboard session timeout
- Dictionary, Snippets, Saved places
- Accent colour (4 swatches)
- Export (JSON to Files), debug timing overlay

---

## 12. Build and install without a Mac

1. **Project:** XcodeGen `ios/project.yml`, checked in. Never commit a hand-edited `.xcodeproj`.
2. **CI** `.github/workflows/ios.yml` on the newest macOS runner with Xcode 26:
   - `swift test` for FridayCore
   - `brew install xcodegen && xcodegen generate`
   - `xcodebuild -scheme Friday -sdk iphoneos -configuration Release CODE_SIGNING_ALLOWED=NO CODE_SIGNING_REQUIRED=NO build`
   - zip `Payload/Friday.app` (with `PlugIns/`) → `Friday.ipa`; build number = run number
   - publish to the GitHub Release `latest` and update `ios/sidestore-source.json` (AltStore/SideStore source format). The phone then sees updates inside SideStore: add the source once, tap Update.
   - The repo is public, so macOS minutes are free.
3. **Install:** SideStore → Sources → add the raw URL of `ios/sidestore-source.json` → install Friday. SideStore re-signs with the free Apple ID and rewrites the extension and App Group IDs.
4. **Refresh:** every 7 days in SideStore (or its background refresh). Data survives refreshes and updates. Never delete the app.
5. **Free Apple ID budget:** 4 App IDs (app + keyboard + widget + share) out of 10 per 7 days. SideStore counts as one of the 3 active apps.

---

## 13. Build order (everything ships; this is just the order)

1. **Install probe:** the minimal app plus all 3 extensions, App Group, keychain sharing, background audio, and HealthKit + AlarmKit + Location usage keys. It shows a screen reporting what works: App Group read/write from the keyboard, the keyboard opening the app, HealthKit authorisation, AlarmKit authorisation. CI → install via SideStore → the owner sends a screenshot. **Anything free signing blocks moves to the Shortcuts bridge.** Don't build further until this works.
2. FridayCore with tests: models, actions, validation, apply, undo, rollover, dates, snippets.
3. Today UI (per `ios/design/` + result card), store, long-press edit, Settings, first-run checklist.
4. Audio + SpeechAnalyzer live transcript + Talking sheet.
5. AI layer: OpenAI-compatible client, Groq Whisper chunking, race, quota tracker, Gemini + Foundation Models fallbacks, timing overlay.
6. Command brain end to end on the day list: highlights, Undo pill. Evals file + runner.
7. Keyboard: voice bar, IPC, session/bounce, ✓ insert with context, → Friday, ✨ rewrite.
8. Action button: AudioRecordingIntent + Live Activity + App Shortcuts.
9. EventKit mirror + read calendars, notifications.
10. Abilities: contacts, messages, calls, alarms/timers, location reminders + saved places, health, music, Notion, Shortcuts, open.
11. Web answers (Gemini grounding, Tavily) and the Gmail bridge script + client.
12. Share extension + OCR.
13. Tune on the phone: latency, VAD thresholds, prompts against real speech (add each miss to the evals).

**Time:** roughly 3–5 days of calendar time, mostly waiting on CI rounds, the owner's testing and Claude usage limits.

---

## 14. Limits (where the line is)

**Can:** everything in §5. Dictate into any app and read the text in the box being typed in. Calendar, Reminders, Contacts, Location, Health*, Photos. Alarms*, timers, local notifications, Live Activities, Action button, Siri/Shortcuts. Prepare messages, emails and calls. Anything with a web API.

**Cannot (iOS blocks every app, no matter the permissions):**
- Read WhatsApp/Instagram/iMessage chats, other apps' notifications, or the screen.
- Send WhatsApp/iMessage or place calls by itself (one tap from you, always).
- Tap buttons or control other apps.
- Always-on "Hey Friday" when no session is running.
- Server push notifications, iCloud sync (paid developer account only).
- Type in password fields or apps that block third-party keyboards.

\* depends on the install probe; the fallback is the Shortcuts bridge.

---

## 15. Risks and fallbacks

| Risk | Fallback |
|---|---|
| Keyboard → app bounce needs a manual swipe back (iOS 26.4+) | Once per session only. The Action button path never needs it |
| Free signing rejects HealthKit / AlarmKit / keychain sharing | Shortcuts bridge / App Group file for keys |
| Groq free limits or models change | Config file, quota tracker, Gemini → on-device chain |
| Gemini free grounding changes | Tavily search |
| Background mic session drains battery | Idle timeout (default 15 min) |

---

## 16. Design reference
`ios/design/` (HTML artboards, 390×844): `Main.dc.html` (Today), `Listening.dc.html` (Talking), `Updated.dc.html` (after a command). The result card and keyboard follow the same look.

**Tokens:** background `#F2F2F7`, cards `#FFFFFF` radius 16, separators `#E3E3E8`, text `#111114`, secondary `#5F5F66`, accent `#4338CA`, change tint `#EEF0FF`, stop red `#D92D20`, undo pill `#111114`. SF system font. Build it in native SwiftUI, not as a web port.

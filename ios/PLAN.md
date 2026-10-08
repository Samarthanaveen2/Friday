# Friday for iPhone — the plan

Single source of truth for the Friday iOS app. Read `RISKS.md` alongside it: its 🔴 items are part of the build. Build all of it; there is no v1/v2. Section 12 is the build order.

- **Device:** iPhone 16 Pro, iOS 26. English only.
- **Constraints:** no paid Apple Developer account, no usable Mac. Built by GitHub Actions, installed with SideStore on a free Apple ID (re-signed every 7 days).
- **Priorities:** fast, accurate, free. Privacy is not a goal: cloud is fine.
- **Style:** it never talks back. No replies, no chat, no assistant voice, no history screens, no stats.

---

## 1. Friday is two things

1. **Friday Keyboard: a one-to-one Wispr Flow clone.** Works in any app. Tap 🎤, talk, tap ✓, and clean, correct text appears in the box. Dictation only: it never answers, never runs commands, never saves anything to the schedule.
2. **Friday app: your day, by voice.** Open the app, tap 🎤, say what's on your plate / what you finished / what's priority, tap **Done**. The Today schedule updates. No replies.

The two never mix. The keyboard writes text; the app manages the schedule.

---

## 2. Friday Keyboard (Wispr Flow clone)

### 2.1 What Wispr Flow does (research, Oct 2026) and what we copy

| Wispr Flow feature | Friday |
|---|---|
| Custom keyboard + main app holding the mic ("Flow session") | ✅ Same design |
| Cloud speech-to-text + LLM cleanup; target **≤700 ms after you stop talking** (Wispr's own budget: ~200 ms ASR, ~200 ms LLM, ~200 ms network) | ✅ Same target and budget (§5) |
| Filler removal (um, uh, pauses) | ✅ |
| **Backtrack**: "meet Tuesday, wait, Wednesday" → "meet Wednesday" | ✅ |
| Auto punctuation from pauses and tone, plus spoken marks ("comma", "new line") | ✅ |
| Numbered and bulleted lists from speech | ✅ |
| Name spelling from surrounding context | ✅ uses the text already in the box |
| **Dictionary**: manual words + auto-added when you correct a spelling | ✅ manual; auto-add is a setting, **off by default** |
| **Snippets**: spoken cue → saved text ("my email") | ✅ |
| Whisper mode (quiet speech) | ✅ mic gain + voice processing |
| Action button | ✅ starts a session (§2.4) |
| Styles per app, Command Mode | ❌ desktop-only in Wispr (and iOS 26.4 hides which app you're in) |
| 100+ languages | ❌ English only |
| History, team sharing, dashboards | ❌ not needed |

### 2.2 Layout
A compact voice bar with minimal keys. Not a full QWERTY (see RISKS A8).
```
[ live transcript strip / status line                     ]
[ 🌐 ]  [ 1?# ]   (  🎤 big  )   [ ⌫ ]  [ return ]
[                 space                  ]
```
- **🎤** starts recording. While recording, it becomes **✓** (stop + insert), with a small **✕** (cancel) beside it.
- **Live transcript strip:** shows words as you speak (on-device recognition), then the status: `Listening…`, `Done`, or a reason on failure (`No internet — used phone`, `Session ended — tap 🎤`).
- **1?#**: one row of numbers and common punctuation.
- **🌐**: switch keyboards (long-press for the list).
- **Paste last:** if an insert was blocked (RISKS A7), a `Paste last` chip appears in the strip.

### 2.3 Flow session (same as Wispr)
1. The first 🎤 in a session opens the Friday app (`friday://session`). The app starts the mic in the foreground (iOS only allows starting it there), then you swipe back along the bottom edge. iOS 26.4+ gives no way to return automatically; Apple confirmed this.
2. The app keeps the mic engine running in the background for the whole session (UIBackgroundModes: audio), discarding audio until you tap 🎤. A Live Activity in the Dynamic Island shows "Friday on".
3. **Session length:** until the phone locks (default) / 15 min / 1 h / never.
4. While the session is live, 🎤 starts instantly with no bounce.
5. **No bounce at all:** start the session *before* opening WhatsApp, via the **Action button** or a **Control Center button**.

### 2.4 Action button / Control Center
- Action button → "Start Friday" (an App Intent). It starts a Flow session using `AudioRecordingIntent` + Live Activity, so iOS lets it start the mic without opening the app. If free signing or iOS blocks that, it opens the app briefly instead.
- The same intent is available as a Control Center control and as a Siri phrase.

### 2.5 Dictation rules (what "gets it right every time" means)
- Your words, your tone, your slang. Never formalised, summarised, answered or expanded.
- A question stays a question: "what time is the meeting?" is typed, not answered.
- Fillers removed, backtracks applied, punctuation and capitals fixed.
- Spoken formatting: "new line", "new paragraph", "comma", "full stop", "question mark", "bullet point", "number one… number two…".
- Numbers and formats: times `5:30`, money `₹500`, emails `name@gmail.com`, links `example.com`, percentages `20%`.
- Continues naturally from the text already in the box: no capital mid-sentence, no doubled words.
- Dictionary spellings always win. Snippet cues expand to their saved text.

---

## 3. Friday app: Today schedule

The only main screen (matches `ios/design/`). Native SwiftUI, stock iOS look.

- **Header:** date in small grey caps, large title **Today**, small gear (Settings) top-right.
- **Focus:** only items you named as priority today. Big rows (18 pt semibold) in a white card. If none named today: `Say what matters today.`
- **Also:** everything else. Small grey rows (15 pt), no card. Read-only events from your calendars (lectures, Google Calendar) appear here with a calendar dot.
- **Next:** one line for the next thing after today: `Next: Project meeting · Sat 16:00`.
- **Rows:** 44 pt checkbox (tap to toggle), title, time on the right. Long-press: Edit, Move to tomorrow, Delete.
- **Mic:** 76 pt accent circle at the bottom.
- **Talking:** a bottom sheet with waveform, live transcript, and **Cancel** / **Done**.
- **After Done:** the sheet closes, changed rows get a light tint and a note (`New`, `Done`, `from 14:00`, `→ Sun`) for ~5 s, and a dark pill `N changes · Undo` sits above the mic.
- **Nothing understood:** the pill says `Didn't catch that` and the transcript stays visible to retry. No other text, ever.

### 3.1 Priority and rollover rules (you decide, the app never guesses)
- You say priorities explicitly, in the same breath or later: "priority today is the warden and the group reply", "make gym top priority", "laundry isn't important".
- Named items → **Focus** (today only). Everything else → **Also**.
- **Rollover** (on the first activity of a new day, and every time the app comes to the foreground): unfinished items from past days move to today, keeping their time of day, and always land in **Also**. Focus resets daily.
- Future-dated items ("Sunday", "tomorrow 10") wait for their day.

### 3.2 Calendar, Reminders, notifications
- Friday's own store is the source of truth. Timed items mirror one-way to a **Friday** calendar and untimed ones to a **Friday** Reminders list (EventKit).
- Local notifications only, and only for **Focus items with a time** (10 min before).

---

## 4. AI stack (free + fast)

All network providers sit behind one **OpenAI-compatible client**. Model IDs live in one config file (`Config/Models.swift`). Check `console.groq.com/docs/models` before hard-coding: the catalogue changes (e.g. `llama-3.1-8b-instant` is reportedly leaving the free tier).

| Job | Primary | Backup 1 | Backup 2 |
|---|---|---|---|
| Live words while talking | **Apple SpeechAnalyzer** (on-device, streaming) | — | — |
| Final transcript | **Groq `whisper-large-v3-turbo`** (`language: en`, `temperature: 0`, `prompt` = dictionary) | SpeechAnalyzer final | — |
| Dictation cleanup | **Groq `openai/gpt-oss-20b`** (`reasoning_effort: low`) | Gemini Flash-Lite | Apple Foundation Models |
| Schedule commands (app only) | **Groq `openai/gpt-oss-120b`** (`reasoning_effort: low`, JSON) | Gemini Flash | Apple Foundation Models (`@Generable`) |

Keys: **Groq** (required), **Gemini** from aistudio.google.com (recommended backup). Both free, no card. Stored in the Keychain; if free signing blocks keychain sharing, in the App Group container.

Free limits (third-party figures, verify in the consoles): Groq Whisper ~2,000 requests/day and ~8 h audio/day, ~20 requests/min; gpt-oss daily token caps; Gemini Flash ~1,500 requests/day. One person's use is far below these. A quota tracker switches to the backup *before* a limit and on any 429/5xx.

---

## 5. Speed (Wispr's 700 ms budget)

Budget after ✓: **~200 ms speech-to-text + ~200 ms cleanup + ~200 ms network**.

1. **Engine always running during a session**, with a 1 s rolling pre-roll buffer prepended to each dictation, so the first word is never lost.
2. **On-device live transcript** the whole time: instant preview and a guaranteed fallback.
3. **Pause chunking** (for dictations > ~20 s): at ≥600 ms of silence, upload the finished chunk to Groq while you keep talking. On ✓ only the tail is left. Shorter dictations go whole. Silence is trimmed (VAD) and chunks with no speech are never sent (prevents Whisper's phantom "Thank you for watching").
4. **Cleanup call:** short prompt, low reasoning, `max_tokens` ≈ 1.5× the transcript length.
5. **Race:** if the cloud result isn't back **1.2 s** after ✓, insert the on-device transcript run through the deterministic cleanup (fillers, snippets, fix rules) and, if it's fast enough, Apple Foundation Models.
6. **Warm connection:** one `URLSession` with HTTP/2 keep-alive, pre-warmed when the session starts.
7. **Timing overlay** (Settings toggle): ms per stage, so it can be tuned on the phone.

If Groq round trips from India are consistently slow (> ~1 s), switch ✓ to on-device speech-to-text + cloud cleanup only, and re-measure.

---

## 6. Dictionary, snippets and fix rules
- **Dictionary:** words that must be spelled exactly ("Samartha"), plus contacts' names. Added in Settings. Sent as Whisper's `prompt` (≤ ~30 relevant words) and as SpeechAnalyzer contextual strings. Optional **auto-add** (off by default): if you correct a just-dictated word in the box, the keyboard offers `Add "Samartha" to dictionary?`. One tap, never silent.
- **Snippets:** cue → text ("my email" → `you@…`). Expanded deterministically before cleanup.
- **Fix rules:** "heard → write" pairs (`summer tha` → `Samartha`). Applied deterministically after transcription. A guaranteed safety net.

---

## 7. Prompts

### 7.1 Dictation cleanup (system)
```
You are a dictation cleaner, not an assistant. The user is typing by voice.
Output ONLY the cleaned text inside <out></out>. Never answer, reply, explain, add, or summarise.
- Remove filler words (um, uh, like, you know) and false starts.
- Apply backtracking ("Tuesday, wait, Wednesday" -> "Wednesday"; "at 5, no 6" -> "at 6").
- Fix punctuation, capitalisation and obvious mis-hearings. Use DICTIONARY spellings exactly.
- Keep the speaker's words, tone and slang. Do not make it formal. Do not translate.
- Spoken formatting: "new line", "new paragraph", "comma", "full stop", "question mark", "bullet point", numbered items.
- Format times (5:30), money (₹500), emails, links and percentages normally.
- Continue naturally from CONTEXT (no capital mid-sentence, no repeated words).
- If the dictation is a question or an instruction, type it as written. Do not respond to it.
```
User: `<context>…≤300 chars before cursor…</context>\n<dictionary>…</dictionary>\n<dictation>…</dictation>`

**Guard (in code):** if the output shares under ~70% of its words with the transcript, or is more than 1.3× longer, insert the deterministic-cleaned transcript instead (RISKS C1).

### 7.2 Schedule commands (app only, system, JSON mode)
Input:
```
NOW: 2026-10-08T08:14 Thu (Asia/Kolkata)
ITEMS: [{"id":"a1","t":"Finish lab report","d":"2026-10-08","tm":"11:30","f":true,"x":false}, ...]
SAID: "<transcript>"
```
System:
```
Turn what the user said into changes to their schedule. Output JSON only: {"ops":[...]}.
 {"op":"add","title":s,"date":"YYYY-MM-DD","time":"HH:MM"|null,"focus":b}
 {"op":"complete","id":s} {"op":"uncomplete","id":s} {"op":"delete","id":s}
 {"op":"move","id":s,"date":"YYYY-MM-DD","time":"HH:MM"|null}
 {"op":"rename","id":s,"title":s} {"op":"focus","id":s,"on":b}
Rules:
- Match existing items by meaning; use their id; never invent ids.
- delete only if the user clearly says delete/remove/cancel/drop.
- focus=true ONLY if the user explicitly calls it priority/important/top/focus.
- Output dates/times as said; keep vague times as said text in "time_said" if unsure.
- Titles short, verb-first when natural, no dates/times inside.
- Nothing schedulable -> {"ops":[]}.
```
**Time rules in code, not the model (RISKS C3):** bare hours 1–7 → PM, 8–11 → AM unless said otherwise. Between 00:00 and 04:00, "tomorrow" = the coming day (today's date). Validate every op (unknown id → choice card; bad date → drop). Apply all ops in one transaction with one undo entry.

### 7.3 Evals
`ios/evals/dictation.jsonl` (≥60 cases: fillers, backtracks, questions that must not be answered, lists, numbers, emails, names, mid-sentence continuation) and `ios/evals/schedule.jsonl` (≥40 cases). `ios/evals/run.sh` runs them against the configured models with a local key and prints pass/fail. Every real miss on the phone becomes a new case.

---

## 8. Architecture

```
Friday (app, SwiftUI)
 ├─ Session     Flow session lifecycle, AVAudioEngine (always on in session), pre-roll, VAD, interruptions,
 │              heartbeat to App Group, music-friendly audio session (mixWithOthers, built-in mic preferred)
 ├─ Speech      SpeechAnalyzer live + Groq Whisper (whole or pause-chunked) + race
 ├─ Clean       deterministic pass (snippets, fix rules, fillers) + LLM cleanup + guard
 ├─ Schedule    command call, validation, apply, undo, rollover, time rules
 ├─ Store       items JSON in the App Group (app is the only writer), daily backup to a Files folder, auto-restore
 ├─ Mirror      EventKit calendar + reminders, read other calendars
 ├─ Notifier    timed Focus items; "refresh in SideStore" 2 days before signing expiry
 └─ Intents     Start Friday (AudioRecordingIntent + Live Activity), Control Center control, App Shortcut
FridayKeyboard (keyboard extension, RequestsOpenAccess = YES)
 └─ voice bar UI only. No audio, no AI, no network. Talks to the app over the App Group.
FridayLive (widget extension)   Live Activity + Control Center control
FridayCore (Swift package, no UIKit/SwiftUI)
 └─ deterministic cleanup, snippets/fix rules, guard, schedule ops, validation, apply, undo, rollover,
    time rules — `swift test` on Linux and in CI
```

- **Keyboard ↔ app:** App Group `group.com.samarth.friday`. The keyboard writes a request (`start`, `stop_insert`, `cancel`) with a request ID plus `documentIdentifier` to a JSON file (atomic write) and posts a Darwin notification. The app replies the same way. The keyboard inserts only if the request ID and `documentIdentifier` still match; otherwise it shows `Paste last`.
- **Bundle IDs (never change after the first install):** `com.samarth.friday`, `.keyboard`, `.live`. That's 3 App IDs out of the free 10/week.
- **Deployment target:** iOS 26.0. Swift 6, SwiftUI, Observation.

---

## 9. Settings and first run
**First run:** one checklist screen. Each row has a status and a Fix button:
- Microphone, Speech, Calendar, Reminders, Notifications.
- Add the Friday keyboard + Full Access.
- Action button / Control Center setup.
- Groq key (required), Gemini key (recommended).
- Backup folder (pick once in Files / iCloud Drive).

**Settings:** keys; session length; dictionary, snippets, fix rules; dictionary auto-add (off); "Use AirPods mic" (off); accent colour; export; timing overlay.

---

## 10. Build and install without a Mac
1. **Project:** XcodeGen `ios/project.yml`. Never commit a hand-edited `.xcodeproj`.
2. **CI** `.github/workflows/ios.yml` on the newest macOS runner with Xcode 26: `swift test` (FridayCore) → `xcodegen generate` → `xcodebuild … -sdk iphoneos CODE_SIGNING_ALLOWED=NO` → zip `Payload/Friday.app` into `Friday.ipa` (build number = run number) → GitHub Release `latest` → update `ios/sidestore-source.json`. The repo is public, so macOS minutes are free.
3. **Install:** SideStore → Sources → add the raw URL of `ios/sidestore-source.json` → install. Updates appear in SideStore.
4. **Refresh** every 7 days (Friday warns 2 days before). Data survives refreshes and updates. Always sign with the same Apple ID (RISKS D1).

---

## 11. Limits
**Can:** dictate into any app that allows third-party keyboards; read the text near the cursor in that box; manage the schedule; Calendar/Reminders mirror; local notifications; Action button, Control Center, Siri.
**Cannot:** password and some secure/banking fields (iOS swaps in its own keyboard); return to the previous app automatically after a session start (iOS 26.4+); know which app you're typing in (iOS 26.4+); read other apps' content; work while the signing has expired.

---

## 12. Build order (everything ships; this is just the order)
1. **Install probe:** minimal app + keyboard + widget, App Group, keychain sharing, background audio, AudioRecordingIntent + Live Activity. It shows a report screen (App Group round trip with the keyboard, keyboard → app open, background mic survives 2 min in another app, intent can start the mic). CI → SideStore install → owner sends a screenshot. Adjust the plan to whatever free signing blocks before going further.
2. FridayCore + tests: deterministic cleanup, guard, schedule ops, validation, undo, rollover, time rules.
3. Session engine: audio session, pre-roll, VAD, interruptions, heartbeat, Live Activity.
4. Speech: SpeechAnalyzer live, Groq Whisper (whole + chunked), race, phantom-text guards.
5. Cleanup: Groq/Gemini/Foundation Models chain, quota tracker, timing overlay, dictation evals.
6. **Keyboard:** voice bar, IPC, session start/bounce, ✓ insert with context, ✕, `Paste last`, status lines, 1?# row. **Daily-usable at this point.**
7. Action button + Control Center start.
8. Today UI, store, backup/restore, long-press edit, Settings, first-run checklist.
9. Schedule commands end to end, highlights, Undo, schedule evals.
10. EventKit mirror + calendar read, notifications, expiry warning.
11. Dictionary, snippets, fix rules, optional auto-add.
12. Tune on the phone: latency, VAD thresholds, prompts against real speech.

---

## 13. Design reference
`ios/design/` (HTML artboards, 390×844): `Main.dc.html` (Today), `Listening.dc.html` (talking sheet; its stop button becomes **Cancel / Done**), `Updated.dc.html` (after Done). The keyboard follows the same look.

**Tokens:** background `#F2F2F7`, cards `#FFFFFF` radius 16, separators `#E3E3E8`, text `#111114`, secondary `#5F5F66`, accent `#4338CA`, change tint `#EEF0FF`, stop red `#D92D20`, pill `#111114`. SF system font. Native SwiftUI, not a web port.

## Sources (Wispr research)
[Wispr: technical challenges (700 ms budget)](https://wisprflow.ai/post/technical-challenges) · [Wispr features](https://wisprflow.ai/features) · [Baseten case study](https://www.baseten.co/resources/customers/wispr-flow/) · [Wispr docs: iPhone keyboard](https://docs.wisprflow.ai/articles/7453988911-set-up-the-flow-keyboard-on-iphone) · [Wispr docs: iOS 26.4](https://docs.wisprflow.ai/articles/6269634092-adapting-to-ios-26-4?lang=en) · [Apple forums: keyboard round trip](https://developer.apple.com/forums/thread/826851) · [Zack Proser: Wispr vs Apple dictation](https://zackproser.com/blog/wisprflow-vs-apple-dictation-2026) · [eesel overview](https://www.eesel.ai/blog/wispr-flow-overview) · [Netolink guide](https://netolink.com/wispr-flow/)

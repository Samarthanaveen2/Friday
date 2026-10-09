# Friday for iPhone — the plan

Single source of truth for the Friday iOS app. Read `RISKS.md` alongside it: its 🔴 items are part of the build. Build all of it; there is no v1/v2. Section 12 is the build order.

- **Device:** iPhone 16 Pro, iOS 26. English only.
- **Constraints:** no paid Apple Developer account, no usable Mac. Built by GitHub Actions, installed with SideStore on a free Apple ID (re-signed every 7 days).
- **Priorities:** fast, accurate, free. Privacy is not a goal: cloud is fine.
- **Style:** low noise. The keyboard never talks back. The app only shows short results when you asked for something (e.g. a web answer). No chat, no assistant voice, no stats.

---

## 1. Friday is two voices

| | **Input voice** | **Input → output voice** |
|---|---|---|
| Where | Friday Keyboard, in any app | Friday app mic, Action button, Siri, Control Center |
| What it does | Types exactly what you said, cleaned up | **Decides** what you meant and **does it** |
| Replies? | Never | Only a short result card when needed |
| Goal | Accuracy and speed (Wispr Flow one-to-one) | Right decision, done in one go |

1. **Friday Keyboard (input voice):** a one-to-one Wispr Flow clone. Tap 🎤, talk, tap ✓, and clean, correct text appears. It never answers, never runs commands, never saves anything.
2. **Friday app (input → output voice):** a decision engine. You say anything ("warden at 3, note: idea for the club poster, text Rahul I'm late, when's the next Arsenal match, play lofi") and tap **Done**. It splits that into actions and runs them: schedule changes, notes, messages, calls, email, web answers, music, alarms and more (§3.3).

The two never mix. The keyboard writes text; the app makes decisions.

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

### 2.2 Layout (copy Wispr Flow's keyboard — see `design/wispr-keyboard-reference.png`)
No letter keys, no autocorrect. For letters, tap 🌐 to switch to Apple's keyboard.

**Idle:**
```
[ ≡ ]                                   [ Tone ] [ 🎤 ]
[ 1 ][ 2 ][ 3 ][ 4 ][ 5 ][ 6 ][ 7 ][ 8 ][ 9 ][ 0 ]
[ - ][ / ][ : ][ ; ][ ( ][ ) ][ ₹ ][ & ][ @ ][ " ]
[ #+= ]  [ . ][ , ][ ? ][ ! ][ ' ]           [ ⌫ ]
[ ABC ]  [          Friday (space)         ]  [ ⏎ ]
(🌐 system globe below)
```
- **Top bar:** ≡ (session on/off, settings shortcut) on the left; **Tone** and **🎤** on the right. Nothing else (no "Start" button).
- **Tone:** cycles the cleanup tone for the next dictation: `As said` (default) → `Casual` → `Formal`. Shows the current one as a small label.
- **Number/symbol pad:** same as iOS's number layout. `#+=` shows the second symbol page. `ABC` switches to the next keyboard (Apple's letters). The space bar reads "Friday".

**Recording (after tapping 🎤):** the whole pad disappears. In the middle, a live **voice-memo style waveform** only — no live words (like Wispr). The text appears all at once after ✓. **✕** (cancel) on the left, **✓** (done → insert) on the right. After insert, the pad comes back.

- **Strip messages** (above the waveform or under the top bar): `Done`, or why it failed (`No internet — used phone`, `Session ended — tap 🎤`), or `Paste last` if an insert was blocked.
- **Undo / Raw (after insert, ~4 s):** the strip shows `Undo · Raw`. **Undo** removes exactly the text Friday just typed (fixes: wrong box, bad result, and deleting a long dictation with ⌫ on a pad with no letters). **Raw** swaps the cleaned text for the plain transcript (fixes: cleanup changed a name or word, without speaking again). Both only act if the text just before the cursor still matches what was inserted; otherwise they do nothing and fade.

### 2.2.1 Look and feel (must match Wispr Flow's polish)
The owner wants it as neat as Wispr Flow. It should look like part of iOS, not a custom app.
- **Keys look exactly like Apple's keyboard:** same key height, gaps, corner radius (~8 pt), key colours and shadow, in light and dark mode (follows the system). Digits 26 pt regular, symbols 22 pt, labels (`ABC`, `#+=`, space) 17 pt. SF system font only.
- **Top bar:** ≡ is a plain SF Symbol (`line.3.horizontal`), no background. On the right, the mic is a **white pill** (black in light mode is fine if white looks wrong) like Wispr's `Start ▮▮▮` pill: rounded capsule, ~44 pt tall, icon `waveform` + `mic.fill`. **Tone** is a small quiet text label (13 pt, secondary colour) just left of the pill, not a button-looking box.
- **Recording view:** same height as the pad, so the keyboard never jumps. Waveform in the middle: thin rounded bars, smooth, ~30 fps, following voice level. **✕** and **✓** are round 44 pt buttons: ✕ grey, ✓ the white pill style. A small timer (`0:12`) under the waveform.
- **Motion:** pad ↔ waveform swap with a short fade + slight scale (~0.2 s). No bouncy or long animations.
- **Haptics:** light tap on every key and on 🎤/✓/✕ (like Apple's keyboard haptics). Success haptic when text is inserted.
- **Hold to repeat** on ⌫ (speeds up like Apple's), and a long-press on space moves the cursor like Apple's.
- **Strip messages:** one line, 13 pt, secondary colour, fade out after 2 s. Never a pop-up or alert.
- **No clutter:** no logos, no emoji, no extra colours. The only accent is the white pill.
- **The app** follows the same rules: stock SwiftUI controls, SF Symbols, system spacing, smooth 0.2 s animations, haptics on taps. Match `ios/design/`.

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
- Your words, your tone, your slang (unless Tone is set to Casual/Formal). Never summarised, answered or expanded.
- A question stays a question: "what time is the meeting?" is typed, not answered.
- Fillers removed, backtracks applied, punctuation and capitals fixed.
- Spoken formatting: "new line", "new paragraph", "comma", "full stop", "question mark", "bullet point", "number one… number two…".
- Numbers and formats: times `5:30`, money `₹500`, emails `name@gmail.com`, links `example.com`, percentages `20%`.
- Continues naturally from the text already in the box: no capital mid-sentence, no doubled words.
- Dictionary spellings always win. Snippet cues expand to their saved text.

---

## 3. Friday app: the decision engine

Three screens, switched with a small segmented control under the title: **Today | Notes | Money**. Native SwiftUI, stock iOS look (Today matches `ios/design/`).

- **Header:** date in small grey caps, large title **Today**, small gear (Settings) top-right.
- **Focus:** only items you named as priority today. Big rows (18 pt semibold) in a white card. If none named today: `Say what matters today.`
- **Also:** everything else. Small grey rows (15 pt), no card. Read-only events from your calendars (lectures, Google Calendar) appear here with a calendar dot.
- **Next:** one line for the next thing after today: `Next: Project meeting · Sat 16:00`.
- **Rows:** 44 pt checkbox (tap to toggle), title, time on the right. Long-press: Edit, Move to tomorrow, Delete.
- **Mic:** 76 pt accent circle at the bottom.
- **Talking:** a bottom sheet with waveform, live transcript, and **Cancel** / **Done**.
- **After Done:** the sheet closes, changed rows get a light tint and a note (`New`, `Done`, `from 14:00`, `→ Sun`) for ~5 s, and a dark pill `N changes · Undo` sits above the mic.
- **Nothing understood:** the pill says `Didn't catch that` and the transcript stays visible to retry. No other text, ever.

- **Result card** (above the mic, only when there's something to show, dismissible):
  - **Answer:** 1–3 lines (a web answer, an email summary).
  - **Ready to send:** a short preview plus one button (`Send on WhatsApp`, `Send email`, `Call Rahul`).
  - **Choice:** when a name is ambiguous ("Rahul S" / "Rahul K").
- **Notes:** a plain list, newest first. Each note is the cleaned text plus the time. Tap to edit, swipe to delete, long-press to copy or share. Notes come from voice ("note: …", "remember this idea…") or from typing. Idea notes show who it came from and your own thoughts (§3.5).
- **Money:** two short lists. **Owed:** one row per person with the net amount (`Rahul owes you ₹150` / `You owe Priya ₹80`); swipe to settle. **Spent:** entries newest first (`Lunch · ₹200 · Thu`). Tap to edit, swipe to delete. No charts. Totals only appear as an answer card when you ask.

### 3.1 Priority and rollover rules (you decide, the app never guesses)
- You say priorities explicitly, in the same breath or later: "priority today is the warden and the group reply", "make gym top priority", "laundry isn't important".
- Named items → **Focus** (today only). Everything else → **Also**.
- **Rollover** (on the first activity of a new day, and every time the app comes to the foreground): unfinished items from past days move to today, keeping their time of day, and always land in **Also**. Focus resets daily.
- Future-dated items ("Sunday", "tomorrow 10") wait for their day.

### 3.2 Calendar, Reminders, notifications
- Friday's own store is the source of truth. Timed items mirror one-way to a **Friday** calendar and untimed ones to a **Friday** Reminders list (EventKit).
- Local notifications only, and only for **Focus items with a time** (10 min before).

### 3.3 Everything the decision engine can do

One utterance can contain several of these; each becomes its own action.

| Ability | Example | How |
|---|---|---|
| **Schedule** | "done with the report, gym to 5, laundry Sunday, priority is warden" | Own store, mirrored to Calendar/Reminders |
| **Notes** | "note: poster idea, blue background, club logo big" | Saved to Notes (cleaned text) |
| **WhatsApp** | "tell Rahul I'll be 10 min late" | Contact lookup → `whatsapp://send?phone=…&text=…`. Opens ready to send; you tap Send |
| **SMS / iMessage** | "text mom I reached" | Message compose sheet (or `sms:` with body). You tap Send |
| **Email (Gmail)** | "email the professor asking for an extension" / "summarise my unread emails" | Gmail bridge (§4.1). Draft in the result card → `Send email`. Summaries → answer card |
| **Calls** | "call warden" | `tel:`. You tap Call |
| **Alarms and timers** | "wake me at 6:30", "timer 20 min" | AlarmKit (iOS 26). Fallback: Shortcuts bridge |
| **Location reminders** | "remind me to buy milk when I reach the market" | `MKLocalSearch` + `CLMonitor` geofence → notification. "This is my hostel" saves the current place |
| **Contacts** | "what's Rahul's number" | `CNContactStore`, fuzzy match, choice card if ambiguous |
| **Web answers** | "when's the next Arsenal match, add it" | Gemini with Google Search grounding; Tavily backup. Answer card, plus actions if asked ("add it") |
| **Music** | "play lofi on Spotify" | Spotify Web API (PKCE; playback control needs Premium) or `spotify:` deep link; Apple Music library via `MPMusicPlayerController` |
| **Health** | "how many steps today" | HealthKit read if free signing allows it; fallback Shortcuts bridge |
| **Notion** | "add this to my Notion" | Notion API, internal integration token |
| **Your Shortcuts** | "run study mode" | `shortcuts://run-shortcut?name=…&input=…` |
| **Open** | "open Instagram", "directions to the station" | URL schemes, Apple Maps URL |
| **Screenshots** | share a screenshot of a notice → Friday | Share extension + Vision OCR → decision engine (can only *add* items or notes without a tap) |
| **Money** | "spent 200 on lunch", "Rahul owes me 150 for the cab", "paid Priya back", "how much did I spend this week?" | Own store (§3.4). Totals and balances are computed in code, never by the model |
| **Ideas memory** | "Kunal said charge more early on, and I think that fits the club fest" … later: "where did the charge-more idea come from?" | §3.5 |

**One-tap rule:** iOS never lets an app send a WhatsApp/iMessage or place a call by itself. Friday prepares it and you tap once. Email through the Gmail bridge could send silently, but still requires the `Send email` tap.

### 3.4 Money
**Money:** amounts in ₹. Each entry: amount, what, date, and optionally a person and direction. Owed balances are per person (net). "Paid Rahul back" / "Rahul paid me" settles the full balance unless an amount is said. Lives in the same store, backup and undo as items and notes.

### 3.5 Ideas memory (never forget where an idea came from)
For advice and ideas you hear (founders, friends, podcasts, books) mixed with your own thoughts. Spoken, never typed. **Nothing is ever overwritten or lost.**

**What one idea holds**
- **Idea:** their point, in their words, cleaned (not summarised).
- **From:** a person or source from the **People & sources** list (below), or none if it's your own idea.
- **Takes:** a timeline of your own thoughts, each with its date. A take is `added` (more thoughts) or `changed` (you changed your mind). Old takes are never edited or removed; the newest is your current view.
- **Topics:** 1–3 tags, picked from your existing topic list first, so `pricing` doesn't also become `price` and `charging`.
- **Links:** related ideas ("this connects to the obsessed-few idea").
- **Raw:** the exact transcript of every recording that touched it, kept as the source of truth.
- Dates: created, and each take.

**People & sources:** one list with aliases, so `Kunal`, `Kunal Shah` and `KS` are the same person. New names are added automatically; an unclear one ("Rahul" when there are two) shows a choice card. You can rename or merge them in Settings.

**Saving (the logic)**
1. You talk. The decision engine gets the ~20 closest existing ideas, your people list and topic list (§7.2).
2. It decides: **new idea**, **add a take** to an existing one, or **changed my mind** on an existing one ("I don't agree with the Kunal thing anymore, now I think…").
3. Before saving a *new* idea, code checks for a very close match (same person and similar meaning). If found, a choice card asks `Add to "obsessed few" (Kunal, 12 Oct)?` / `Save as new`.
4. Everything is saved in one step with **Undo** in the pill (`Saved idea · Undo`, `Added to Kunal's idea · Undo`).

**Asking (the logic)**
1. The model turns your question into a search: words to look for, plus optional filters (person, topic, date range: "last month", "before the fest").
2. Code finds matches: filters first, then a mix of keyword match + meaning match (embeddings) + a small boost for recent ideas. Top ~15.
3. One short call writes the answer and must cite idea ids. Code checks every cited id exists; the card's **from**, **date** and **takes** come from the store, never from the model's text, so the source can't be made up.
4. Answer card: the idea, `from Kunal Shah · 12 Oct`, your **current take**, and `You changed your mind on 3 Nov. Before: …` if there's history. Tap to open the full timeline. Several matches → a short list. Nothing → `Nothing saved about that`.

Questions it handles: "where did this idea come from?", "what did Rahul tell me about startups?", "what have I saved about pricing?", "what did I think about X before?", "what ideas did I save last week?", "everything from Kunal".

**Meaning search (embeddings):** Gemini embedding API (free) as the main one, Apple NaturalLanguage on-device as the offline fallback. Both are stored per idea, so search works offline too. Recomputed when an idea gets a new take.

**Notes screen:** idea notes show the idea, a grey line `from Kunal Shah · 12 Oct`, then your current take. Open one to see the full take timeline (old takes greyed, `changed` ones marked), links and raw recordings. Typed edits create a new take, not an overwrite.

**Kept forever:** append-only (every change is a new record), in the daily backup to iCloud Drive (survives losing the phone), auto-restored after a reinstall. Deleting an idea moves it to **Recently deleted** for 30 days.

---

## 4. AI stack (free + fast)

All network providers sit behind one **OpenAI-compatible client**. Model IDs live in one config file (`Config/Models.swift`). Check `console.groq.com/docs/models` before hard-coding: the catalogue changes (e.g. `llama-3.1-8b-instant` is reportedly leaving the free tier).

| Job | Primary | Backup 1 | Backup 2 |
|---|---|---|---|
| Hidden backup transcript while talking (never shown in the keyboard) | **Apple SpeechAnalyzer** (on-device, streaming) | — | — |
| Final transcript | **Groq `whisper-large-v3-turbo`** (`language: en`, `temperature: 0`, `prompt` = dictionary) | SpeechAnalyzer final | — |
| Dictation cleanup | **Groq `openai/gpt-oss-20b`** (`reasoning_effort: low`) | Gemini Flash-Lite | Apple Foundation Models |
| Decision engine (app only) | **Groq `openai/gpt-oss-120b`** (`reasoning_effort: low`, JSON) | Gemini Flash | Apple Foundation Models (`@Generable`, schedule + notes only) |
| Web answers | **Gemini Flash + Google Search grounding** | Tavily search → Groq 120b summarises | "Can't search right now" |
| OCR (screenshots) | **Apple Vision** (on-device) | — | — |

Keys: **Groq** (required), **Gemini** from aistudio.google.com (recommended: backup + web answers), **Tavily** (search backup). All free, no card. Stored in the Keychain; if free signing blocks keychain sharing, in the App Group container.

Free limits (third-party figures, verify in the consoles): Groq Whisper ~2,000 requests/day and ~8 h audio/day, ~20 requests/min; gpt-oss daily token caps; Gemini Flash ~1,500 requests/day. One person's use is far below these. A quota tracker switches to the backup *before* a limit and on any 429/5xx.

### 4.1 Integrations (all free, set up once)
| Service | Setup | Stored in |
|---|---|---|
| **Gmail bridge** | A Google Apps Script web app in your own Google account (`ios/integrations/gmail-bridge.gs`), deployed "Execute as me"; paste its URL + a secret. Endpoints: `unread_summary`, `search`, `draft`, `send`. No weekly OAuth expiry | Settings → Gmail |
| Google Calendar | Add the Google account in iOS Settings → Calendar; Friday reads it via EventKit | — |
| Notion | notion.so/my-integrations → token; share the target page with it | Settings → Notion |
| Spotify | Spotify developer app (dev mode) → client ID; PKCE login | Settings → Spotify |

---

## 5. Speed (Wispr's 700 ms budget)

Budget after ✓: **~200 ms speech-to-text + ~200 ms cleanup + ~200 ms network**.

1. **Engine always running during a session**, with a 1 s rolling pre-roll buffer prepended to each dictation, so the first word is never lost.
2. **On-device transcript runs silently** the whole time: not shown, only used as the instant fallback if the cloud is slow or offline.
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
- **Fix rules:** "heard → write" pairs (`summer tha` → `Samartha`). Applied deterministically after transcription. A guaranteed safety net. **Whole words only**, ignoring case (a rule for `sam` must never change `same`). Same for snippet cues. Entries are trimmed and duplicates dropped.

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

### 7.2 Decision engine (app only, system, JSON mode)
Input:
```
NOW: 2026-10-08T08:14 Thu (Asia/Kolkata)
ITEMS: [{"id":"a1","t":"Finish lab report","d":"2026-10-08","tm":"11:30","f":true,"x":false}, ...]
PLACES: ["hostel","market"]
PEOPLE_OWED: {"Rahul":150,"Priya":-80}
IDEAS: [{"id":"i7","from":"Kunal Shah","idea":"build for the obsessed few","take":"start with the 20 regulars"}, ...]   (only the ~20 closest to SAID)
PEOPLE: [{"id":"p3","name":"Kunal Shah","aka":["Kunal","KS"]}, ...]
TOPICS: ["club","pricing", ...]
SAID: "<transcript>"
```
System:
```
Decide what the user wants done and output the actions. JSON only: {"actions":[...]}.
Schedule:
 {"a":"add","title":s,"date":"YYYY-MM-DD","time":"HH:MM"|null,"focus":b,"place":s|null}
 {"a":"complete","id":s} {"a":"uncomplete","id":s} {"a":"delete","id":s}
 {"a":"move","id":s,"date":"YYYY-MM-DD","time":"HH:MM"|null}
 {"a":"rename","id":s,"title":s} {"a":"focus","id":s,"on":b}
Other:
 {"a":"note","text":s}
 {"a":"idea","idea":s,"from":s|null,"take":s|null,"topics":[s],"links":[id]}
 {"a":"take","id":s,"text":s,"kind":"added"|"changed"}
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
 {"a":"spend","amount":n,"what":s,"date":"YYYY-MM-DD"}
 {"a":"owe","person":s,"amount":n,"dir":"they_owe"|"i_owe","what":s|null}
 {"a":"settle","person":s,"amount":n|null}
 {"a":"ask","kind":"web"|"email"|"health"|"contacts"|"notes"|"ideas"|"money","query":s,"from":s|null,"topic":s|null,"after":"YYYY-MM-DD"|null,"before":"YYYY-MM-DD"|null}
Rules:
- One utterance can hold many actions; output all of them in order.
- Match existing items by meaning; use their id; never invent ids.
- delete only if the user clearly says delete/remove/cancel/drop.
- focus=true ONLY if the user explicitly calls it priority/important/top/focus.
- "note"/"remember this" -> note with the user's words cleaned, not summarised.
- Advice or an idea from someone or somewhere, or the user's own idea worth keeping -> "idea". Put the other person's point in idea, the user's own thoughts in take. Never merge them, never summarise.
- More thoughts on a saved idea -> "take" kind "added"; the user disagreeing with their old view -> kind "changed". Use its id from IDEAS.
- "from": use the name from PEOPLE when it matches an alias. Topics: reuse TOPICS when one fits.
- Messages and emails: write the text the user would send, in their voice.
- Use "ask" only when an answer needs outside info, your notes, or money totals. Never do money maths yourself.
- Titles short, no dates/times inside. Nothing actionable -> {"actions":[]}.
```
**In code, not the model:** time rules (bare hours 1–7 → PM, 8–11 → AM; between 00:00 and 04:00 "tomorrow" = today's date), validation (unknown id or contact → choice card; bad date → drop), one transaction and one undo entry for all schedule/note/money actions. Each `ask` runs its fetch (web/Gmail/HealthKit/Contacts/notes search/money totals computed in code), then one short call writes a 1–3 line answer and any follow-up actions ("add it"). Everything else finishes in one call.

### 7.3 Evals
`ios/evals/dictation.jsonl` (≥60 cases: fillers, backtracks, questions that must not be answered, lists, numbers, emails, names, mid-sentence continuation) and `ios/evals/decisions.jsonl` (≥60 cases across all abilities). `ios/evals/run.sh` runs them against the configured models with a local key and prints pass/fail. Every real miss on the phone becomes a new case.

---

## 8. Architecture

```
Friday (app, SwiftUI)
 ├─ Session     Flow session lifecycle, AVAudioEngine (always on in session), pre-roll, VAD, interruptions,
 │              heartbeat to App Group, music-friendly audio session (mixWithOthers, built-in mic preferred)
 ├─ Speech      SpeechAnalyzer live + Groq Whisper (whole or pause-chunked) + race
 ├─ Clean       deterministic pass (snippets, fix rules, fillers) + LLM cleanup + guard
 ├─ Decide      decision call, validation, apply, undo, rollover, time rules, ask → fetch → answer
 ├─ Abilities   Notes, Contacts, Messages, Mail (Gmail bridge), Calls, AlarmKit, Location (CLMonitor),
 │              Web (Gemini/Tavily), Music, HealthKit, Notion, Shortcuts, Open, Money,
 │              Ideas memory (people/aliases, take timeline, Gemini + NaturalLanguage embeddings, hybrid search)
 ├─ Store       items JSON in the App Group (app is the only writer); ideas in SQLite (append-only, embeddings as blobs);
 │              daily zipped backup to a Files/iCloud Drive folder (keep last 7), auto-restore
 ├─ Mirror      EventKit calendar + reminders, read other calendars
 ├─ Notifier    timed Focus items; "refresh in SideStore" 2 days before signing expiry
 └─ Intents     Start Friday (AudioRecordingIntent + Live Activity), Control Center control, App Shortcut
FridayKeyboard (keyboard extension, RequestsOpenAccess = YES)
 └─ voice bar UI only. No audio, no AI, no network. Talks to the app over the App Group.
FridayLive (widget extension)   Live Activity + Control Center control
FridayShare (share extension)   screenshots/text → OCR → decision engine
FridayCore (Swift package, no UIKit/SwiftUI)
 └─ deterministic cleanup, snippets/fix rules, guard, schedule ops, validation, apply, undo, rollover,
    time rules, money balances/totals, ideas: take timeline, alias matching, duplicate check, hybrid ranking, citation check — `swift test` on Linux and in CI
```

- **Keyboard ↔ app:** App Group `group.com.samarth.friday`. The keyboard writes a request (`start`, `stop_insert`, `cancel`) with a request ID plus `documentIdentifier` to a JSON file (atomic write) and posts a Darwin notification. The app replies the same way. The keyboard inserts only if the request ID and `documentIdentifier` still match; otherwise it shows `Paste last`.
- **Bundle IDs (never change after the first install):** `com.samarth.friday`, `.keyboard`, `.live`, `.share`. That's 4 App IDs out of the free 10/week.
- **Deployment target:** iOS 26.0. Swift 6, SwiftUI, Observation.

---

## 9. Settings and first run
**First run:** one checklist screen. Each row has a status and a Fix button:
- Microphone, Speech, Calendar, Reminders, Notifications, Contacts, Location (Always), Health.
- Add the Friday keyboard + Full Access.
- Action button / Control Center setup.
- Keys: Groq (required), Gemini (recommended), Tavily; Gmail bridge, Notion, Spotify (optional).
- Backup folder (pick once in Files / iCloud Drive).

**Settings:** keys and integrations; saved places; session length; dictionary, snippets, fix rules; dictionary auto-add (off); "Use AirPods mic" (off); accent colour; export; timing overlay.

---

## 9.1 Storage
- **App:** ~15–30 MB (app + 3 extensions, no AI models inside). Apple's speech and AI models are part of iOS and shared, not counted against Friday.
- **Data per idea:** ~1 KB text + ~1 KB raw transcript + ~5 KB embeddings ≈ **7 KB**. 5 ideas a day for 5 years ≈ 9,000 ideas ≈ **65 MB**. Items, notes and money are tiny (a few MB over years). No audio is kept.
- **Backups:** last 7 days, zipped: roughly the same again.
- **Total:** under ~150 MB even after years of daily use.

## 10. Build and install without a Mac
1. **Project:** XcodeGen `ios/project.yml`. Never commit a hand-edited `.xcodeproj`.
2. **CI** `.github/workflows/ios.yml` on the newest macOS runner with Xcode 26: `swift test` (FridayCore) → `xcodegen generate` → `xcodebuild … -sdk iphoneos CODE_SIGNING_ALLOWED=NO` → zip `Payload/Friday.app` into `Friday.ipa` (build number = run number) → GitHub Release `latest` → update `ios/sidestore-source.json`. The repo is public, so macOS minutes are free.
3. **Install:** SideStore → Sources → add the raw URL of `ios/sidestore-source.json` → install. Updates appear in SideStore.
4. **Refresh** every 7 days (Friday warns 2 days before). Data survives refreshes and updates. Always sign with the same Apple ID (RISKS D1).

---

## 11. Limits
**Can:** dictate into any app that allows third-party keyboards; read the text near the cursor in that box; everything in §3.3; Calendar/Reminders mirror; local notifications; Action button, Control Center, Siri.
**Cannot:** password and some secure/banking fields (iOS swaps in its own keyboard); return to the previous app automatically after a session start (iOS 26.4+); know which app you're typing in (iOS 26.4+); read other apps' content (WhatsApp/Instagram chats, notifications, screen); send a message or place a call without your tap; work while the signing has expired.

---

## 12. Build order (everything ships; this is just the order)
1. **Install probe:** minimal app + keyboard + widget, App Group, keychain sharing, background audio, AudioRecordingIntent + Live Activity. It shows a report screen (App Group round trip with the keyboard, keyboard → app open, background mic survives 2 min in another app, intent can start the mic). CI → SideStore install → owner sends a screenshot. Adjust the plan to whatever free signing blocks before going further.
2. FridayCore + tests: deterministic cleanup, guard, schedule ops, validation, undo, rollover, time rules.
3. Session engine: audio session, pre-roll, VAD, interruptions, heartbeat, Live Activity.
4. Speech: SpeechAnalyzer live, Groq Whisper (whole + chunked), race, phantom-text guards.
5. Cleanup: Groq/Gemini/Foundation Models chain, quota tracker, timing overlay, dictation evals.
6. **Keyboard:** voice bar, IPC, session start/bounce, ✓ insert with context, ✕, `Paste last`, status lines. **Daily-usable at this point.**
7. Action button + Control Center: **double use** — in the app's settings choose what the Action button does: "Start keyboard session" or "Talk to Friday" (decision engine without opening the app, via AudioRecordingIntent + Live Activity). Default: Talk to Friday; the Control Center button starts the keyboard session.
8. Today UI, store, backup/restore, long-press edit, Settings, first-run checklist.
9. Decision engine on schedule + notes: highlights, Undo, Notes screen, evals.
10. EventKit mirror + calendar read, notifications, expiry warning.
11. Abilities: contacts, messages, calls, alarms/timers, location reminders, music, Health, Notion, Shortcuts, open.
12. Web answers (Gemini grounding, Tavily), Gmail bridge script + client, result card.
13. Share extension + OCR.
14. Dictionary, snippets, fix rules, optional auto-add.
15. Money screen + actions; ideas memory (people, takes timeline, duplicate check, hybrid search, cited answers), with ≥30 ideas eval cases.
16. Tune on the phone: latency, VAD thresholds, prompts against real speech.

---

## 13. Design reference
`ios/design/` (HTML artboards, 390×844): `Main.dc.html` (Today), `Listening.dc.html` (talking sheet; its stop button becomes **Cancel / Done**), `Updated.dc.html` (after Done). Notes, the result card and the keyboard follow the same look.

**Tokens:** background `#F2F2F7`, cards `#FFFFFF` radius 16, separators `#E3E3E8`, text `#111114`, secondary `#5F5F66`, accent `#4338CA`, change tint `#EEF0FF`, stop red `#D92D20`, pill `#111114`. SF system font. Native SwiftUI, not a web port.

## Sources (Wispr research)
[Wispr: technical challenges (700 ms budget)](https://wisprflow.ai/post/technical-challenges) · [Wispr features](https://wisprflow.ai/features) · [Baseten case study](https://www.baseten.co/resources/customers/wispr-flow/) · [Wispr docs: iPhone keyboard](https://docs.wisprflow.ai/articles/7453988911-set-up-the-flow-keyboard-on-iphone) · [Wispr docs: iOS 26.4](https://docs.wisprflow.ai/articles/6269634092-adapting-to-ios-26-4?lang=en) · [Apple forums: keyboard round trip](https://developer.apple.com/forums/thread/826851) · [Zack Proser: Wispr vs Apple dictation](https://zackproser.com/blog/wisprflow-vs-apple-dictation-2026) · [eesel overview](https://www.eesel.ai/blog/wispr-flow-overview) · [Netolink guide](https://netolink.com/wispr-flow/)

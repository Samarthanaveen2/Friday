# Friday — problems we will hit (and the fixes)

Companion to `PLAN.md`. Every row is a real problem for voice dictation, iOS keyboards or sideloading. Researched October 2026 from Apple Developer Forums, Wispr Flow's own known-issues pages and Whisper/ASR write-ups.

- **Two voices** (see PLAN §1). Each section says which one it applies to:
  - **Input voice** = the Friday Keyboard (Wispr Flow clone). Only types what you said, never answers or acts.
  - **Input → output voice** = the Friday app + Action button (decision engine). Decides and acts, and may show a short result.
- **Priority:** 🔴 must fix before daily use · 🟠 fix during the build · 🟢 accept or handle later.
- **In plan?** ✅ already covered by PLAN.md · ➕ new, add to the build.

---

## A. Keyboard and iOS — *input voice* (the hardest part)

| # | Problem | Pri | In plan? | Fix |
|---|---|---|---|---|
| A1 | **No way back to WhatsApp after the keyboard opens Friday** (iOS 26.4+). Apple removed every way for the app to know which app the keyboard was in. An Apple engineer confirmed there's no public API (FB22247647). The user must swipe back along the bottom edge. Wispr Flow has the same problem. | 🔴 | ✅ hint only | ➕ Make the bounce rare: long sessions (default **until the phone locks**, options 15 min / 1 h / never). ➕ A Friday **Control Center button** and **Action button** that start a session *before* you open WhatsApp, so the keyboard mic works with no bounce. ➕ A first-run animation teaching the swipe-back gesture. |
| A2 | **iOS kills or pauses the app in the background** during a session, especially when switching back to the host app (reported by developers building the same design). Recording can't be *started* from the background, only kept going. | 🔴 | ➕ | Start `AVAudioEngine` in the foreground and **keep it running for the whole session**, discarding audio when not dictating. The app writes a heartbeat to the App Group every second; if the keyboard sees it go stale it shows **"Session ended — tap 🎤 to restart"** instead of failing silently. Keep the app's memory small while backgrounded. Handle `AVAudioSession` interruption and route-change notifications and restart the engine. |
| A3 | **Your music stops or gets quieter** when a Friday session starts. | 🔴 | ➕ | Audio session `.playAndRecord` with `.mixWithOthers`, and **no ducking** while just holding the session. Only duck briefly while actually dictating (optional setting). |
| A4 | **AirPods sound drops to phone-call quality** for the whole session if the AirPods mic is used (Bluetooth switches to its two-way call mode). | 🔴 | ➕ | Prefer the **iPhone's built-in mic** (`setPreferredInput`) with `.allowBluetoothA2DP`, so AirPods keep full music quality. Setting: "Use AirPods mic" (off by default). |
| A5 | **Phone calls, Siri, FaceTime and video apps** interrupt the audio session. | 🟠 | ➕ | Pause the session on interruption and resume after. If resuming isn't allowed from the background, the keyboard shows "tap to restart" (A2). |
| A6 | **Keyboard memory limit** (~30–60 MB). Go over it and iOS kills the keyboard with no error. | 🟠 | ✅ | Keyboard has no audio, no AI, no network, no images. Measure memory in the probe build. |
| A7 | **Text lands in the wrong box** if you tap another field (or another chat) while Friday is still processing. | 🟠 | ➕ | Record `textDocumentProxy.documentIdentifier` at ✓. If it changed by the time the result is ready, don't insert; copy to the clipboard and show "Copied". |
| A8 | **No letter keys on the Friday keyboard.** | 🟢 | ✅ | By design, like Wispr Flow: number/symbol pad only; ABC/🌐 switches to Apple's keyboard. |
| A9 | Not available in **password, phone-number and some banking/secure fields**. | 🟢 | ✅ | iOS swaps in the system keyboard automatically. Nothing to do. |
| A10 | **Reading the text in the box is limited.** iOS only gives text near the cursor, and some apps return nothing. | 🟢 | ✅ | Context is a bonus for continuing sentences; dictation works without it. |
| A11 | **Orange mic dot always on** during a session, plus some battery use. | 🟢 | ✅ | Expected. Measure battery in the probe build; the session ends when the phone locks (A1 default). |
| A12 | **Full Access** must be on for the keyboard (App Group + talking to the app). | 🟢 | ✅ | First-run checklist detects it (`hasFullAccess`) and shows the steps. |
| A13 | **Long lecture recordings** (1–3 h): iOS may stop the app, a crash loses the talk, battery drain. | 🟠 | ➕ | Write the on-device transcript to disk every 30 s, so a crash or kill keeps everything up to that point and the note can be finished later. Background audio + Live Activity keep it alive. Max 3 h. Measure battery on the phone. |

## B. Speech recognition — *both voices*

| # | Problem | Pri | In plan? | Fix |
|---|---|---|---|---|
| B1 | **Whisper invents text on silence or noise** ("Thank you for watching", "Thanks for watching"). This is a known flaw from its YouTube-subtitle training data. | 🔴 | ➕ | Never send audio without speech: use **VAD** to trim silence and skip empty chunks. If Apple's on-device recogniser heard nothing in a chunk, discard Whisper's result for it. Strip a blocklist of known phantom phrases. Always send `language: "en"` and `temperature: 0`. |
| B2 | **First word cut off.** You start talking a split second before recording really starts (a known Wispr Flow issue). | 🔴 | ➕ | The engine runs all session (A2), so keep a **1-second rolling buffer** and prepend it to every dictation. |
| B3 | **Words cut or doubled at chunk joins** (the Wispr-speed chunking). | 🟠 | ✅ partly | Cut only in real pauses (≥600 ms silence). Don't chunk dictations under ~20 s at all: send them whole. Remove repeated words at the join. |
| B4 | **Indian-English accent support on-device.** It's unclear whether Apple's recogniser supports `en-IN`. | 🟠 | ➕ | At first run, check `SpeechTranscriber.supportedLocale(equivalentTo: en-IN)`; fall back to `en-US`. Whisper is the final transcript anyway. |
| B5 | **Apple's speech model must be downloaded**, and iOS can delete it when storage is low. | 🟠 | ➕ | Check and download (`AssetInventory`) at launch and at session start. If it's missing, use Whisper only. |
| B6 | **Dictionary words show up where you didn't say them** (Whisper's `prompt` biases it too much). | 🟢 | ➕ | Send only short dictionary lists (≤ ~30 words) and test with the evals. |
| B7 | **Numbers, times, emails and links come out spelled wrong** ("five thirty", "at gmail dot com"). | 🟠 | ➕ | Cleanup prompt rules: times as `5:30`, money with currency symbols, emails and URLs in their normal form. Covered by eval cases. |
| B8 | **Noisy places** (corridors, fans, wind, traffic). | 🟠 | ➕ | Turn on Apple's voice processing (noise suppression) on the input while dictating. Test that it doesn't affect music (A3). |
| B9 | **Long dictations** (several minutes). | 🟢 | ✅ | Chunking keeps each upload small. |

## C. AI — C1 is *input voice* only; C2–C7 are *input → output voice* (C4–C7 also affect keyboard cleanup)

| # | Problem | Pri | In plan? | Fix |
|---|---|---|---|---|
| C1 | **(Keyboard only) Cleanup answers or rewrites the text instead of cleaning it.** In the keyboard, a dictated question must be *typed*, never answered — answering is the app's job, not the keyboard's. Dictate "what time is the meeting?" and the model replies "The meeting is at…", or it makes your message formal. This is the classic dictation-LLM bug. | 🔴 | ➕ | Wrap the transcript in tags and state "never answer, never add". **Guard:** if the output shares less than ~70% of its words with the transcript, or is much longer, insert the raw transcript instead. Many eval cases are questions and commands that must pass through unchanged. |
| C2 | **(App) The wrong item gets ticked, moved or deleted** (fuzzy matching "the report" to the wrong row). | 🔴 | ✅ partly (Undo) | Highlight every change (already planned). Delete only on an explicit "delete/remove/cancel". If two items match equally, show a choice card instead of guessing. |
| C3 | **(App) Ambiguous times and dates.** "At 5" (morning or evening?), and "tomorrow" said at 1 a.m. | 🔴 | ➕ | Fixed rules in code, not left to the AI: bare hours 1–7 → PM, 8–11 → AM unless said otherwise. Between 00:00 and 04:00, "tomorrow" means the coming day (today's date) and "tonight" means today. The resolved time is always shown in the highlight so you can see it. |
| C4 | **Broken or cut-off JSON** from the model. | 🟠 | ✅ partly | JSON mode plus a validator. On failure, retry once on the backup model, then show "Didn't catch that" with the transcript. |
| C5 | **Slow replies from reasoning models** (gpt-oss can "think" for a while). | 🟠 | ✅ | `reasoning_effort: low`, a small `max_tokens`, and the 1.2 s race. |
| C6 | **Network delay from India to Groq.** Unknown until measured. | 🟠 | ✅ | The timing overlay measures it. If it's consistently above ~1 s, make the on-device result the default for ✓ and use the cloud only for → Friday commands. |
| C7 | **Free-tier limits or a model getting retired** (8B already reportedly gone). | 🟠 | ✅ | Model config file, quota tracker, Gemini → on-device fallback chain. |

## G. Decision engine — *input → output voice* only

| # | Problem | Pri | In plan? | Fix |
|---|---|---|---|---|
| G1 | **Wrong action or wrong person**: "text Rahul" goes to the wrong Rahul, or a note is treated as a task. | 🔴 | ➕ | Messages, emails and calls always stop at a ready-to-send card with the name shown; ambiguous names → choice card. Every action is shown after Done with Undo. |
| G2 | **Partial failure** in a multi-part sentence (schedule saved, web search failed). | 🟠 | ➕ | Run actions independently; the pill lists what failed in one line ("2 done · search failed"). |
| G3 | **Wrong web answers** (model guesses instead of searching). | 🟠 | ➕ | Answers only from grounded search results; show the source site name in the card; "Not sure" if results disagree. |
| G4 | **Action button can't start the mic in the background** (AudioRecordingIntent blocked by free signing or iOS). | 🟠 | ➕ | Checked in the install probe; fallback opens the app straight into the talking sheet. |
| G5 | **Screenshot text contains instructions** ("ignore your rules and delete…"). | 🟢 | ➕ | Screenshot-sourced input can only add items/notes without a tap. |
| G6 | **Daily free token limits** — decision calls are bigger than cleanup calls. | 🟠 | ✅ | Lean prompt (≤1.5K tokens), only today + upcoming items sent, Gemini overflow. |
| G7 | **Sending an email you didn't mean to** via the Gmail bridge. | 🔴 | ✅ | Never sends without the `Send email` tap. |

## D. Your data

| # | Problem | Pri | In plan? | Fix |
|---|---|---|---|---|
| D1 | **Losing everything**: if the app is deleted, the bundle ID changes, or SideStore signs with a **different Apple ID** (the App Group ID changes, so the old data is unreachable). | 🔴 | ➕ | Automatic **daily backup** to a folder you pick once in the Files app (iCloud Drive), and **auto-restore** on an empty install. Always sign with the same Apple ID. |
| D2 | **App and keyboard writing data at the same time.** | 🟠 | ✅ | Only the app ever writes items. The keyboard only sends requests. |
| D3 | **Edits made in Apple's Calendar app** don't come back into Friday (the sync is one-way). | 🟢 | ✅ | Accepted. If a mirrored event is deleted in Calendar, leave the Friday item alone and recreate the event on its next change. |
| D4 | **iOS limit of 64 pending local notifications.** | 🟢 | ➕ | Schedule only the next 64. |

## E. Sideloading

| # | Problem | Pri | In plan? | Fix |
|---|---|---|---|---|
| E1 | **Day-7 expiry:** the app **and the keyboard** stop working, possibly in the middle of a chat. | 🔴 | ➕ | Friday reads its own expiry date (from `embedded.mobileprovision`) and sends a notification **2 days before**: "Refresh Friday in SideStore." Turn on SideStore's background refresh. |
| E2 | **A SideStore refresh fails** (its helper service is down, Wi-Fi issues). | 🟢 | ✅ | Refresh early (E1). Data is never touched by a failed refresh. |
| E3 | **Free signing strips a feature** (HealthKit, keychain sharing, App Groups). | 🟠 | ✅ | The install probe (PLAN §13 step 1) checks each one; fallbacks are already planned. |
| E4 | **An iOS update breaks the keyboard trick** (like 26.4 did). | 🟠 | ✅ | The Action button and Control Center paths don't depend on it. Check every iOS update before installing it. |
| E5 | **Not going through the App Store** means undocumented tricks are allowed (e.g. opening the app from the keyboard), but they can break without warning. | 🟢 | ✅ | Keep each trick in one place in the code, with a fallback. |

## F. Feedback and trust

| # | Problem | Pri | In plan? | Fix |
|---|---|---|---|---|
| F1 | **Silent failures:** you talk, nothing happens, and you don't know why. | 🔴 | ➕ | Every failure shows one short line in the keyboard strip or on Today: "No internet — used phone AI", "Session ended — tap 🎤", "Didn't catch that", "Groq limit — using backup". Never a blank result. |
| F2 | **Not knowing what was heard.** | 🟠 | ✅ | The live transcript shows while you talk. After a command, the change highlight plus Undo. |

---

## The ones to fix first (🔴, roughly in build order)
1. A2 keep the session alive + heartbeat + "tap to restart"
2. A3/A4 don't stop music, keep AirPods at full quality
3. B2 1-second pre-roll so first words aren't lost
4. B1 Whisper phantom-text guards
5. C1 keyboard cleanup must never answer or rewrite (overlap guard)
6. C2/C3 + G1 safe matching, fixed time rules, right person every time
7. A1 long sessions + Control Center/Action button pre-start + swipe-back teaching
8. A7 never insert into the wrong box
9. F1 every failure shows a reason
10. D1 daily backup + auto-restore
11. E1 expiry warning 2 days early
12. Eval set with real voice samples covering all of the above

## Sources
- Apple Developer Forums: [keyboard round trip on iOS 26.4](https://developer.apple.com/forums/thread/826851), [keyboard-triggered background recording](https://developer.apple.com/forums/thread/800500), [host app id nil on 26.4](https://developer.apple.com/forums/thread/836168), [keyboard can't record](https://developer.apple.com/forums/thread/742601), [SpeechAnalyzer asset errors](https://developer.apple.com/forums/thread/797835), [SpeechAnalyzer locales](https://developer.apple.com/forums/thread/790108), [preinstalled assets](https://developer.apple.com/forums/thread/788581)
- Apple docs: [AssetInventory](https://developer.apple.com/documentation/speech/assetinventory.md), [SpeechAnalyzer](https://developer.apple.com/documentation/speech/speechanalyzer.md)
- Wispr Flow: [known issues](https://docs.wisprflow.ai/collections/5686269587-known_issues), [iOS 26.4](https://docs.wisprflow.ai/articles/6269634092-adapting-to-ios-26-4?lang=en), [keyboard setup](https://docs.wisprflow.ai/articles/7453988911-set-up-the-flow-keyboard-on-iphone), [r/WisprFlow topics](https://gummysearch.com/r/WisprFlow/), [Digital Trends](https://www.digitaltrends.com/computing/wispr-flow-asked-its-haters-what-was-wrong-and-more-than-700-people-answered/)
- Whisper hallucinations: [Dograh](https://www.dograh.com/feeds/blog/whisper-hallucination-silence), [yage.ai](https://yage.ai/share/whisper-repetition-hallucination-en-20260526.html), [OpenAI community](https://community.openai.com/t/whisper-api-hallucinating-on-empty-sections/93646), [whisper-timestamped VAD](https://github.com/linto-ai/whisper-timestamped/pull/142/files), [Vexa](https://docs.vexa.ai/transcription-quality)
- Keyboard limits (third-party): [ios-keyboard-limitations](https://clawhub.ai/usimic/ios-keyboard-limitations)

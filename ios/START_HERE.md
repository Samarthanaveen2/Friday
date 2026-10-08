# Start here (continuing on another Claude account)

## 1. Give the new account the repo
1. Log into the friend's Claude account → claude.ai/code.
2. Connect **your** GitHub (Samarthanaveen2) to that account when it asks, so it can push to `Samarthanaveen2/Friday`. (The repo is public, so it can always read it; pushing needs your GitHub connected.)
3. Start a new session on the repo `Samarthanaveen2/Friday`.

## 2. Paste this as the first message

```
Read CLAUDE.md and ios/PLAN.md fully. We're building the Friday iPhone app described there, for my iPhone 16 Pro on iOS 26. I have no Mac and no paid Apple developer account: you write the code, GitHub Actions builds an unsigned .ipa, and I install it with SideStore.

Start with step 1 of the build order (the install probe): XcodeGen project, empty app + keyboard + widget extensions, App Group, background audio, and the GitHub Actions workflow that publishes Friday.ipa to a GitHub Release tagged "latest". Push it, watch CI until it's green, then tell me in 3 short lines how to install it. Keep your messages short.
```

After that works, say "next step" each time, or "build the rest" to let it go through the whole build order.

## 3. Things you do once
- **SideStore**: install it on your iPhone (needs a computer once — your 2017 Air is fine). Guide: sidestore.io.
- **Groq API key** (free): console.groq.com → API Keys → Create. You paste it into Friday's Settings later.
- Optional: a separate free Apple ID just for SideStore signing.

## Files
- `ios/PLAN.md` — the full spec (features, AI pipeline, prompts, architecture, build, limits).
- `ios/design/` — the agreed screen mockups.

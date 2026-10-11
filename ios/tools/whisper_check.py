"""Checks Groq Whisper settings the app relies on, with spoken test audio (espeak-ng).

1. Groq accepts the compressed .m4a (AAC) the app sends for long dictations.
2. The spoken-style prompt (Dictation.verbatimStyle) keeps self-corrections word for word
   and never leaks into short clips.
Usage: python3 whisper_check.py <dir with .wav/.m4a files named case.ext>  (GROQ_API_KEY set)
"""
import json, os, sys, time, urllib.request, uuid

STYLE = "Umm, let me think like, hmm... Okay, here's what I'm, like, thinking."
KEY = os.environ["GROQ_API_KEY"]


def transcribe(path, prompt):
    boundary = uuid.uuid4().hex
    name = os.path.basename(path)
    mime = "audio/mp4" if name.endswith(".m4a") else "audio/wav"
    parts = []
    for k, v in [("model", "whisper-large-v3-turbo"), ("language", "en"), ("temperature", "0"),
                 ("response_format", "json")] + ([("prompt", prompt)] if prompt else []):
        parts.append(f'--{boundary}\r\nContent-Disposition: form-data; name="{k}"\r\n\r\n{v}\r\n'.encode())
    parts.append(f'--{boundary}\r\nContent-Disposition: form-data; name="file"; filename="{name}"\r\n'
                 f'Content-Type: {mime}\r\n\r\n'.encode())
    body = b"".join(parts) + open(path, "rb").read() + f"\r\n--{boundary}--\r\n".encode()
    req = urllib.request.Request("https://api.groq.com/openai/v1/audio/transcriptions", data=body, headers={
        "Authorization": f"Bearer {KEY}", "Content-Type": f"multipart/form-data; boundary={boundary}",
        "User-Agent": "Friday/1.0"})
    try:
        with urllib.request.urlopen(req, timeout=30) as r:
            return r.status, json.loads(r.read())["text"].strip()
    except urllib.error.HTTPError as e:
        return e.code, e.read()[:200].decode(errors="replace")


folder = sys.argv[1]
bad = 0
for name in sorted(os.listdir(folder)):
    path = os.path.join(folder, name)
    for label, prompt in [("no prompt", ""), ("style", STYLE)]:
        status, text = transcribe(path, prompt)
        leak = prompt and any(w in text.lower() for w in ["let me think", "here's what i'm", "thinking"])
        flag = "OK " if status == 200 and not leak else "BAD"
        if flag == "BAD":
            bad += 1
        print(f"{flag} {name:28} [{label:9}] {status} {text!r}")
        time.sleep(3.5)
print(f"\n{bad} bad")
sys.exit(1 if bad else 0)

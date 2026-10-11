"""Speech bench: how many words does each speech-to-text setup lose on real, long dictations?

Runs every clip in ios/speechbench through each setup (compressed to .m4a like the app sends),
aligns the result with the verbatim reference and counts missing words, especially "skips":
runs of 3+ reference words in a row that never appear. Usage:
  python3 speech_bench.py <bench dir> <setup> [<setup> ...]    (GROQ_API_KEY set)
  setup = model[+prompt], e.g. whisper-large-v3-turbo+prompt
"""
import json, os, re, subprocess, sys, tempfile, time, urllib.request, uuid, statistics

STYLE = "Umm, let me think like, hmm... Okay, here's what I'm, like, thinking."
KEY = os.environ["GROQ_API_KEY"]


def transcribe(path, model, prompt):
    boundary = uuid.uuid4().hex
    fields = [("model", model), ("language", "en"), ("temperature", "0"), ("response_format", "json")]
    if prompt:
        fields.append(("prompt", prompt))
    body = b"".join(f'--{boundary}\r\nContent-Disposition: form-data; name="{k}"\r\n\r\n{v}\r\n'.encode() for k, v in fields)
    body += (f'--{boundary}\r\nContent-Disposition: form-data; name="file"; filename="audio.m4a"\r\n'
             f'Content-Type: audio/mp4\r\n\r\n').encode() + open(path, "rb").read() + f"\r\n--{boundary}--\r\n".encode()
    req = urllib.request.Request("https://api.groq.com/openai/v1/audio/transcriptions", data=body, headers={
        "Authorization": f"Bearer {KEY}", "Content-Type": f"multipart/form-data; boundary={boundary}",
        "User-Agent": "Friday/1.0"})
    for attempt in range(4):
        start = time.time()
        try:
            with urllib.request.urlopen(req, timeout=60) as r:
                return json.loads(r.read())["text"].strip(), time.time() - start
        except urllib.error.HTTPError as e:
            msg = e.read()[:300].decode(errors="replace")
            if e.code == 429 and attempt < 3:
                print(f"    429, waiting: {msg[:120]}")
                time.sleep(20)
                continue
            raise SystemExit(f"HTTP {e.code}: {msg}")


def words(text):
    return re.findall(r"[a-z0-9']+", text.lower().replace("’", "'"))


def align(ref, hyp):
    """Levenshtein word alignment -> list of ops ('ok'|'sub'|'del'|'ins', ref_word)."""
    n, m = len(ref), len(hyp)
    d = [[0] * (m + 1) for _ in range(n + 1)]
    for i in range(n + 1): d[i][0] = i
    for j in range(m + 1): d[0][j] = j
    for i in range(1, n + 1):
        for j in range(1, m + 1):
            d[i][j] = min(d[i-1][j-1] + (ref[i-1] != hyp[j-1]), d[i-1][j] + 1, d[i][j-1] + 1)
    ops, i, j = [], n, m
    while i or j:
        if i and j and d[i][j] == d[i-1][j-1] + (ref[i-1] != hyp[j-1]):
            ops.append(("ok" if ref[i-1] == hyp[j-1] else "sub", ref[i-1])); i -= 1; j -= 1
        elif i and d[i][j] == d[i-1][j] + 1:
            ops.append(("del", ref[i-1])); i -= 1
        else:
            ops.append(("ins", hyp[j-1])); j -= 1
    return ops[::-1]


def skips(ops, length=3):
    runs, cur = [], []
    for op, w in ops:
        if op == "del": cur.append(w)
        elif op != "ins":
            if len(cur) >= length: runs.append(" ".join(cur))
            cur = []
    if len(cur) >= length: runs.append(" ".join(cur))
    return runs


bench, setups = sys.argv[1], sys.argv[2:]
cases = json.load(open(os.path.join(bench, "manifest.json")))
tmp = tempfile.mkdtemp()
for c in cases:
    src = os.path.join(bench, c["id"] + ".ogg")
    c["m4a"] = os.path.join(tmp, c["id"] + ".m4a")
    subprocess.run(["ffmpeg", "-loglevel", "error", "-y", "-i", src, "-ar", "16000", "-ac", "1",
                    "-c:a", "aac", "-b:a", "32k", c["m4a"]], check=True)

summary = []
for setup in setups:
    model, _, opt = setup.partition("+")
    prompt = STYLE if opt == "prompt" else ""
    totals = {"ref": 0, "sub": 0, "del": 0, "ins": 0}
    all_skips, times = [], []
    print(f"\n=== {setup} ===")
    for c in cases:
        text, secs = transcribe(c["m4a"], model, prompt)
        times.append(secs)
        ref = words(c["text"])
        ops = align(ref, words(text))
        counts = {k: sum(1 for o, _ in ops if o == k) for k in ("sub", "del", "ins")}
        totals["ref"] += len(ref)
        for k in counts: totals[k] += counts[k]
        sk = skips(ops)
        all_skips += [(c["id"], s) for s in sk]
        print(f"{c['id']} {c['seconds']:5.1f}s  WER {100*sum(counts.values())/len(ref):5.1f}%  missing {counts['del']:3d}  skips {len(sk)}  {secs:.2f}s")
        for s in sk:
            print(f"      skipped: \"{s}\"")
        time.sleep(3.2)
    wer = 100 * (totals["sub"] + totals["del"] + totals["ins"]) / totals["ref"]
    summary.append((setup, wer, 100 * totals["del"] / totals["ref"], len(all_skips),
                    sum(len(s.split()) for _, s in all_skips), statistics.median(times)))

print("\n| setup | WER | missing words | skips (3+ words) | words in skips | median time |")
print("|---|---|---|---|---|---|")
for s in summary:
    print(f"| {s[0]} | {s[1]:.1f}% | {s[2]:.1f}% | {s[3]} | {s[4]} | {s[5]:.2f}s |")

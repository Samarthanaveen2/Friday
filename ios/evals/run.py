"""Dictation evals against real models.

  python3 ios/evals/run.py                     # full run on the app's cleanup model
  python3 ios/evals/run.py --screen            # try every Groq chat model on a sample, rank them
  python3 ios/evals/run.py --models a,b        # full run on the given models

Needs GROQ_API_KEY. Uses the app's system prompt and message format (FridayCore Dictation.swift).
A case passes when the output matches an expected answer, ignoring case, spacing and a final full stop.
"""
import argparse, json, os, re, statistics, sys, threading, time, urllib.error, urllib.request

HERE = os.path.dirname(os.path.abspath(__file__))
SRC = os.path.join(HERE, "..", "FridayCore", "Sources", "FridayCore")
DICTIONARY = ["Samartha", "Kharagpur", "Arjun", "Priya"]
SKIP = ("whisper", "guard", "tts", "playai", "orpheus", "distil", "allam", "compound", "safeguard")


def app_model():
    src = open(os.path.join(SRC, "AI", "Providers.swift"), encoding="utf-8").read()
    return re.search(r'groqCleanup = "([^"]+)"', src).group(1)


def system_prompt():
    src = open(os.path.join(SRC, "Dictation", "Dictation.swift"), encoding="utf-8").read()
    body = src.split('public static let systemPrompt = """', 1)[1].split('"""', 1)[0]
    return "\n".join(line.strip() for line in body.strip("\n").splitlines())


def norm(text):
    text = text.lower().replace("’", "'")
    text = re.sub(r"[ \t]+", " ", text)
    text = re.sub(r"\s*\n\s*", "\n", text)
    return text.strip().rstrip(".!")


def out(reply):
    m = re.search(r"<out>(.*?)(</out>|$)", reply or "", re.S)
    return (m.group(1) if m else (reply or "")).strip()


def request(key, path, body=None):
    req = urllib.request.Request("https://api.groq.com/openai/v1/" + path,
                                 data=json.dumps(body).encode() if body else None,
                                 headers={"Authorization": f"Bearer {key}", "Content-Type": "application/json",
                                          "User-Agent": "FridayEvals/1.0"})
    try:
        with urllib.request.urlopen(req, timeout=40) as r:
            return json.load(r)
    except urllib.error.HTTPError as e:
        raise RuntimeError(f"HTTP {e.code}: {e.read()[:160]!r}") from None


def body_for(model, system, user):
    body = {"model": model, "temperature": 0, "max_tokens": 1500,
            "messages": [{"role": "system", "content": system}, {"role": "user", "content": user}]}
    if "gpt-oss" in model:
        body["reasoning_effort"] = "low"
        body["include_reasoning"] = False
    elif "qwen" in model:
        body["reasoning_effort"] = "none"
    return body


def run_model(key, model, cases, system, results):
    rows, times = [], []
    for case in cases:
        user = (f"<context>{case['context'][-300:]}</context>\n<dictionary>{', '.join(DICTIONARY)}</dictionary>\n"
                f"<dictation>{case['say']}</dictation>")
        start = time.time()
        for attempt in range(3):
            try:
                got = out(request(key, "chat/completions", body_for(model, system, user))["choices"][0]["message"].get("content"))
                break
            except Exception as e:  # noqa: BLE001
                got = f"ERROR {e}"
                if "429" in str(e):
                    time.sleep(8)
                    continue
                break
        times.append((time.time() - start) * 1000)
        ok = norm(got) in {norm(e) for e in case["expect"]}
        rows.append((case, got, ok))
        time.sleep(2.2)  # free tier: 30 requests per minute per model
    results[model] = (rows, times)


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--screen", action="store_true")
    ap.add_argument("--models", default="")
    args = ap.parse_args()
    key = os.environ.get("GROQ_API_KEY")
    if not key:
        print("GROQ_API_KEY not set; skipping evals.")
        return 0
    system = system_prompt()
    cases = [json.loads(l) for l in open(os.path.join(HERE, "dictation.jsonl"), encoding="utf-8")]

    if args.screen:
        ids = sorted(m["id"] for m in request(key, "models")["data"])
        print("Groq models:", ", ".join(ids))
        models = [m for m in ids if not any(s in m.lower() for s in SKIP)]
        cases = cases[::3]  # every third case: a quick, varied sample
    else:
        models = [m for m in args.models.split(",") if m] or [app_model()]

    results = {}
    threads = [threading.Thread(target=run_model, args=(key, m, cases, system, results)) for m in models]
    for t in threads:
        t.start()
    for t in threads:
        t.join()

    ranking = []
    for model in models:
        rows, times = results[model]
        passed = sum(ok for _, _, ok in rows)
        ranking.append((passed, -statistics.median(times), model))
        print(f"\n===== {model}: {passed}/{len(rows)} passed, median {statistics.median(times):.0f} ms")
        for case, got, ok in rows:
            if not ok:
                print(f"FAIL #{case['id']}: {case['say']!r}\n      got: {got!r}\n   expect: {case['expect'][0]!r}")
    print("\nRANKING")
    for passed, neg_ms, model in sorted(ranking, reverse=True):
        print(f"  {passed:2d}/{len(cases)}  {-neg_ms:6.0f} ms  {model}")
    return 0


if __name__ == "__main__":
    sys.exit(main())

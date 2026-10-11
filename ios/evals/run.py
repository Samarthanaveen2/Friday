"""Runs the dictation evals against the cleanup model and prints pass/fail.

Usage: GROQ_API_KEY=... python3 ios/evals/run.py [--model openai/gpt-oss-20b]
Uses the same system prompt and message format as the app (FridayCore Dictation.swift).
A case passes when the cleaned text matches one of the expected answers, ignoring case,
spaces and trailing punctuation differences.
"""
import argparse, json, os, re, sys, time, urllib.error, urllib.request

HERE = os.path.dirname(os.path.abspath(__file__))
SWIFT = os.path.join(HERE, "..", "FridayCore", "Sources", "FridayCore", "Dictation", "Dictation.swift")
DICTIONARY = ["Samartha", "Kharagpur", "Arjun", "Priya"]


def system_prompt():
    src = open(SWIFT, encoding="utf-8").read()
    body = src.split('public static let systemPrompt = """', 1)[1].split('"""', 1)[0]
    return "\n".join(line.strip() for line in body.strip("\n").splitlines())


def norm(text):
    text = text.lower().replace("’", "'")
    text = re.sub(r"[ \t]+", " ", text)
    text = re.sub(r"\s*\n\s*", "\n", text)
    return text.strip().rstrip(".!")


def out(reply):
    m = re.search(r"<out>(.*?)</out>", reply, re.S)
    return (m.group(1) if m else reply).strip()


def call(key, model, system, user):
    body = json.dumps({"model": model, "temperature": 0, "max_tokens": 1200, "reasoning_effort": "low", "include_reasoning": False,
                       "messages": [{"role": "system", "content": system}, {"role": "user", "content": user}]}).encode()
    req = urllib.request.Request("https://api.groq.com/openai/v1/chat/completions", data=body,
                                 headers={"Authorization": f"Bearer {key}", "Content-Type": "application/json",
                                          # Groq's firewall blocks Python's default user agent.
                                          "User-Agent": "FridayEvals/1.0"})
    try:
        with urllib.request.urlopen(req, timeout=30) as r:
            return json.load(r)["choices"][0]["message"]["content"]
    except urllib.error.HTTPError as e:
        raise RuntimeError(f"HTTP {e.code}: {e.read()[:200]!r}") from None


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--model", default="openai/gpt-oss-20b")
    args = ap.parse_args()
    key = os.environ.get("GROQ_API_KEY")
    if not key:
        print("GROQ_API_KEY not set; skipping evals.")
        return 0
    system = system_prompt()
    passed = 0
    cases = [json.loads(l) for l in open(os.path.join(HERE, "dictation.jsonl"), encoding="utf-8")]
    for case in cases:
        user = f"<context>{case['context'][-300:]}</context>\n<dictionary>{', '.join(DICTIONARY)}</dictionary>\n<dictation>{case['say']}</dictation>"
        try:
            got = out(call(key, args.model, system, user))
        except Exception as e:  # noqa: BLE001
            got = f"ERROR {e}"
        ok = norm(got) in {norm(e) for e in case["expect"]}
        passed += ok
        mark = "PASS" if ok else "FAIL"
        print(f"{mark} #{case['id']}: {case['say']!r}\n      got: {got!r}" + ("" if ok else f"\n   expect: {case['expect'][0]!r}"))
        time.sleep(2.1)  # stay under the free per-minute limit
    print(f"\n{passed}/{len(cases)} passed")
    return 0


if __name__ == "__main__":
    sys.exit(main())

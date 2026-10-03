// Turns the text typed after the trigger prefix into an action.
// Pure functions only, so it runs in the service worker and in Node tests.

export const DEFAULT_PREFIX = ";;";

const SEARCH = {
  google: (q) => `https://www.google.com/search?q=${encodeURIComponent(q)}`,
  youtube: (q) => `https://www.youtube.com/results?search_query=${encodeURIComponent(q)}`,
  github: (q) => `https://github.com/search?q=${encodeURIComponent(q)}`,
  maps: (q) => `https://www.google.com/maps/search/${encodeURIComponent(q)}`,
  wiki: (q) => `https://en.wikipedia.org/wiki/Special:Search?search=${encodeURIComponent(q)}`,
  claude: (q) => `https://claude.ai/new?q=${encodeURIComponent(q)}`,
  chatgpt: (q) => `https://chatgpt.com/?q=${encodeURIComponent(q)}`,
};

const VERBS = {
  search: "google", s: "google", g: "google", google: "google",
  yt: "youtube", youtube: "youtube",
  gh: "github", github: "github",
  maps: "maps", map: "maps",
  wiki: "wiki",
  ask: "claude", claude: "claude",
  gpt: "chatgpt", chatgpt: "chatgpt",
};

const SITE_ALIASES = {
  gmail: "https://mail.google.com",
  insta: "https://www.instagram.com",
  ig: "https://www.instagram.com",
  yt: "https://www.youtube.com",
  gpt: "https://chatgpt.com",
  claude: "https://claude.ai",
};

const LABELS = {
  google: "Searching Google",
  youtube: "Searching YouTube",
  github: "Searching GitHub",
  maps: "Opening Maps",
  wiki: "Searching Wikipedia",
  claude: "Asking Claude",
  chatgpt: "Asking ChatGPT",
};

// Accepts "github.com", "https://x.y/z" or a bare name like "instagram".
// Returns an http(s) URL string, or null for anything else (javascript:, data:, ...).
export function toUrl(input) {
  const s = input.trim();
  if (!s || /\s/.test(s)) return null;
  const alias = SITE_ALIASES[s.toLowerCase()];
  if (alias) return alias;
  let candidate = s;
  // "scheme:" but not "host:port" — so javascript:… is rejected while localhost:3000 is fine.
  if (!/^[a-z][a-z0-9+.-]*:(?!\d)/i.test(s)) {
    if (/^localhost\b/i.test(s)) candidate = `http://${s}`;
    else candidate = s.includes(".") ? `https://${s}` : `https://${s}.com`;
  }
  try {
    const url = new URL(candidate);
    return url.protocol === "http:" || url.protocol === "https:" ? url.href : null;
  } catch {
    return null;
  }
}

function looksLikeAddress(s) {
  return /^(https?:\/\/)?(localhost|[\w-]+(\.[\w-]+)+)(:\d+)?(\/\S*)?$/i.test(s);
}

// Returns { action: "open", url, label } | { action: "switch", query, fallbackUrl, label }
//       | { action: "note", text, label } | null
export function parseCommand(raw) {
  const text = (raw ?? "").trim();
  if (!text) return null;

  const [head, ...rest] = text.split(/\s+/);
  const verb = head.toLowerCase();
  const arg = rest.join(" ");

  if (VERBS[verb] && arg) {
    const engine = VERBS[verb];
    return { action: "open", url: SEARCH[engine](arg), label: `${LABELS[engine]}: ${arg}` };
  }

  if (verb === "open" && arg) {
    const url = toUrl(arg);
    if (url) return { action: "open", url, label: `Opening ${arg}` };
  }

  if ((verb === "go" || verb === "tab") && arg) {
    return { action: "switch", query: arg, fallbackUrl: toUrl(arg), label: `Switching to ${arg}` };
  }

  if (verb === "note" && arg) {
    return { action: "note", text: arg, label: "Saved to notes" };
  }

  if (looksLikeAddress(text)) {
    const url = toUrl(text);
    if (url) return { action: "open", url, label: `Opening ${text}` };
  }

  return { action: "open", url: SEARCH.google(text), label: `${LABELS.google}: ${text}` };
}

// Picks the best open tab for "go <query>": title or hostname containing the query.
export function pickTab(tabs, query, currentTabId) {
  const q = query.trim().toLowerCase();
  if (!q) return null;
  const host = (t) => {
    try { return new URL(t.url).hostname.toLowerCase(); } catch { return ""; }
  };
  const candidates = tabs.filter((t) => t.id !== currentTabId);
  return (
    candidates.find((t) => host(t).includes(q)) ||
    candidates.find((t) => (t.title || "").toLowerCase().includes(q)) ||
    null
  );
}

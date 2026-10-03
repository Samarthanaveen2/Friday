// Watches every text field on every page. When you press Enter and the text
// before the caret contains the trigger prefix (default ";;"), the command is
// cut out of the field, sent to the background worker, and the page never sees
// the Enter. Nothing is read or sent unless the prefix is there.

(() => {
  let prefix = ";;";
  chrome.storage.sync.get({ prefix }).then((s) => (prefix = s.prefix || prefix));
  chrome.storage.onChanged.addListener((changes, area) => {
    if (area === "sync" && changes.prefix) prefix = changes.prefix.newValue || ";;";
  });

  const TEXT_INPUT_TYPES = new Set(["text", "search", "url", "tel", ""]);

  // Capture phase on window: runs before Gmail/ChatGPT/Instagram handlers send the message.
  window.addEventListener("keydown", onKeyDown, true);

  function onKeyDown(e) {
    if (e.key !== "Enter" || e.shiftKey || e.altKey || e.ctrlKey || e.metaKey) return;
    if (e.isComposing || e.keyCode === 229) return; // IME candidate selection

    const el = e.composedPath()[0];
    const found = findCommand(el);
    if (!found) return;

    e.preventDefault();
    e.stopImmediatePropagation();
    found.remove();

    chrome.runtime
      .sendMessage({ type: "friday:run", text: found.command })
      .then((res) => toast(res?.label || "Done", res?.ok !== false))
      .catch((err) => toast(`Friday is unavailable: ${err.message}`, false));
  }

  function findCommand(el) {
    if (!(el instanceof Element)) return null;
    if (el instanceof HTMLTextAreaElement) return fromTextControl(el);
    if (el instanceof HTMLInputElement) {
      return TEXT_INPUT_TYPES.has(el.type) ? fromTextControl(el) : null; // never passwords
    }
    if (el.isContentEditable) return fromContentEditable(el);
    return null;
  }

  function fromTextControl(el) {
    const value = el.value;
    const end = el.selectionEnd ?? value.length;
    if (el.selectionStart !== end) return null;
    const lineStart = value.lastIndexOf("\n", end - 1) + 1;
    const line = value.slice(lineStart, end);
    const idx = line.lastIndexOf(prefix);
    if (idx < 0) return null;
    const command = line.slice(idx + prefix.length).trim();
    if (!command) return null;

    return {
      command,
      remove() {
        el.setRangeText("", lineStart + idx, end, "end");
        el.dispatchEvent(new Event("input", { bubbles: true }));
      },
    };
  }

  function fromContentEditable(el) {
    const sel = el.ownerDocument.getSelection();
    if (!sel || !sel.rangeCount || !sel.isCollapsed) return null;
    const caret = sel.getRangeAt(0);

    // Scope the search to the current paragraph/block so text elsewhere in an email is ignored.
    const block = closestBlock(caret.startContainer, el);
    const before = document.createRange();
    before.setStart(block, 0);
    before.setEnd(caret.startContainer, caret.startOffset);
    const text = before.toString();
    const idx = text.lastIndexOf(prefix);
    if (idx < 0) return null;
    const command = text.slice(idx + prefix.length).trim();
    if (!command) return null;

    return {
      command,
      remove() {
        const start = pointAtOffset(block, idx);
        if (!start) return;
        const r = document.createRange();
        r.setStart(start.node, start.offset);
        r.setEnd(caret.startContainer, caret.startOffset);
        sel.removeAllRanges();
        sel.addRange(r);
        // execCommand fires beforeinput/input, which rich editors (ProseMirror, Draft, Lexical) listen to.
        document.execCommand("delete");
      },
    };
  }

  function closestBlock(node, root) {
    let n = node.nodeType === Node.ELEMENT_NODE ? node : node.parentElement;
    while (n && n !== root) {
      const display = getComputedStyle(n).display;
      if (display !== "inline" && display !== "contents") return n;
      n = n.parentElement;
    }
    return root;
  }

  // Maps a character offset within block.textContent-order text nodes back to a DOM point.
  function pointAtOffset(block, offset) {
    const walker = document.createTreeWalker(block, NodeFilter.SHOW_TEXT);
    let remaining = offset;
    for (let t = walker.nextNode(); t; t = walker.nextNode()) {
      if (remaining <= t.data.length) return { node: t, offset: remaining };
      remaining -= t.data.length;
    }
    return null;
  }

  let toastHost;
  function toast(message, ok) {
    if (!toastHost || !toastHost.isConnected) {
      toastHost = document.createElement("friday-toast");
      const root = toastHost.attachShadow({ mode: "closed" });
      root.innerHTML = `
        <style>
          div { position: fixed; z-index: 2147483647; right: 16px; bottom: 16px; max-width: 360px;
                padding: 10px 14px; border-radius: 10px; font: 13px/1.4 system-ui, sans-serif;
                color: #fff; background: #1f2937; box-shadow: 0 6px 24px rgba(0,0,0,.25);
                opacity: 0; transform: translateY(8px); transition: opacity .15s, transform .15s; }
          div.show { opacity: 1; transform: none; }
          div.err { background: #b91c1c; }
        </style><div></div>`;
      toastHost._box = root.querySelector("div");
      document.documentElement.appendChild(toastHost);
    }
    const box = toastHost._box;
    box.textContent = `Friday · ${message}`;
    box.className = ok ? "show" : "show err";
    clearTimeout(box._timer);
    box._timer = setTimeout(() => (box.className = ""), 2200);
  }
})();

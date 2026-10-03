import { parseCommand, pickTab } from "./commands.js";

chrome.runtime.onMessage.addListener((msg, sender, sendResponse) => {
  if (msg?.type !== "friday:run") return;
  run(msg.text, sender.tab).then(sendResponse, (err) =>
    sendResponse({ ok: false, label: `Friday: ${err?.message || err}` })
  );
  return true; // keep the channel open for the async response
});

async function run(text, fromTab) {
  const cmd = parseCommand(text);
  if (!cmd) return { ok: false, label: "Nothing to do" };

  switch (cmd.action) {
    case "open":
      await openTab(cmd.url, fromTab);
      return { ok: true, label: cmd.label };

    case "switch": {
      const tabs = await chrome.tabs.query({});
      const target = pickTab(tabs, cmd.query, fromTab?.id);
      if (target) {
        await chrome.windows.update(target.windowId, { focused: true });
        await chrome.tabs.update(target.id, { active: true });
        return { ok: true, label: cmd.label };
      }
      if (cmd.fallbackUrl) {
        await openTab(cmd.fallbackUrl, fromTab);
        return { ok: true, label: `No tab for "${cmd.query}", opened it` };
      }
      return { ok: false, label: `No tab matching "${cmd.query}"` };
    }

    case "note": {
      const { notes = [] } = await chrome.storage.local.get("notes");
      notes.unshift({ text: cmd.text, url: fromTab?.url || "", at: Date.now() });
      await chrome.storage.local.set({ notes });
      return { ok: true, label: cmd.label };
    }
  }
  return { ok: false, label: "Unknown command" };
}

function openTab(url, fromTab) {
  const props = { url, active: true };
  if (fromTab) {
    props.index = fromTab.index + 1;
    props.windowId = fromTab.windowId;
    props.openerTabId = fromTab.id;
  }
  return chrome.tabs.create(props);
}

const prefixInput = document.getElementById("prefix");
const notesList = document.getElementById("notes");
const clearBtn = document.getElementById("clear");

function showPrefix(prefix) {
  prefixInput.value = prefix;
  document.querySelectorAll(".p").forEach((el) => (el.textContent = prefix));
}

chrome.storage.sync.get({ prefix: ";;" }).then(({ prefix }) => showPrefix(prefix));

prefixInput.addEventListener("input", () => {
  const prefix = prefixInput.value.trim();
  if (!prefix) return;
  document.querySelectorAll(".p").forEach((el) => (el.textContent = prefix));
  chrome.storage.sync.set({ prefix });
});

async function renderNotes() {
  const { notes = [] } = await chrome.storage.local.get("notes");
  notesList.replaceChildren();
  clearBtn.hidden = notes.length === 0;
  if (!notes.length) {
    const li = document.createElement("li");
    li.className = "empty";
    li.textContent = "No notes yet.";
    notesList.append(li);
    return;
  }
  for (const note of notes) {
    const li = document.createElement("li");
    li.textContent = note.text;
    const meta = document.createElement("small");
    let where = "";
    try { where = note.url ? ` · ${new URL(note.url).hostname}` : ""; } catch {}
    meta.textContent = new Date(note.at).toLocaleString() + where;
    li.append(meta);
    notesList.append(li);
  }
}

clearBtn.addEventListener("click", async () => {
  await chrome.storage.local.set({ notes: [] });
  renderNotes();
});

renderNotes();

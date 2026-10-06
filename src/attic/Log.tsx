import { useMemo, useState } from 'react'
import { useLiveQuery } from 'dexie-react-hooks'
import { db } from '../db/db'
import { SearchLinks, TopicPill, type LabEntryX } from './shared'

function safeHref(link: string): string {
  return /^https?:\/\//i.test(link) ? link : `https://${link}`
}

export function EntryCard({ entry, onTopic }: { entry: LabEntryX; onTopic?: (name: string) => void }) {
  const [confirming, setConfirming] = useState(false)
  const date = new Date(entry.createdAt)
  const toggleStar = () => db.lab.update(entry.id!, { starred: !entry.starred })
  const remove = async () => {
    if (!confirming) {
      setConfirming(true)
      window.setTimeout(() => setConfirming(false), 3000)
      return
    }
    await db.lab.delete(entry.id!)
  }
  return (
    <article className={`lab-entry${entry.starred ? ' starred' : ''}`}>
      <div className="lab-entry-head">
        <div className="lab-entry-topics">
          {entry.topics.map((t, i) => (
            <span key={t + i} className="lab-entry-topic">
              {i > 0 && <span className="lab-x">+</span>}
              <TopicPill name={t} onClick={onTopic ? () => onTopic(t) : undefined} />
            </span>
          ))}
        </div>
      </div>
      <div className="lab-entry-meta">
        <span className="lab-entry-date">
          {date.toLocaleDateString(undefined, { year: 'numeric', month: 'short', day: 'numeric' })} ·{' '}
          {date.toLocaleTimeString(undefined, { hour: '2-digit', minute: '2-digit' })}
        </span>
        <div className="lab-entry-actions">
          <button
            className={`lab-icon-btn lab-star-btn${entry.starred ? ' on' : ''}`}
            onClick={toggleStar}
            title={entry.starred ? 'Unstar' : 'Star'}
            aria-label={entry.starred ? 'Unstar' : 'Star'}
            aria-pressed={!!entry.starred}
          >
            {entry.starred ? '★' : '☆'}
          </button>
          <button className={`btn btn-sm btn-ghost ${confirming ? 'lab-confirm' : 'lab-delete'}`} onClick={remove}>
            {confirming ? 'Delete?' : 'Delete'}
          </button>
        </div>
      </div>
      {entry.prompt && <p className="lab-entry-prompt">{entry.prompt}</p>}
      {entry.connection && (
        <div>
          <div className="lab-entry-label">Connection</div>
          <p className="lab-entry-text">{entry.connection}</p>
        </div>
      )}
      {entry.notes && (
        <div>
          <div className="lab-entry-label">Learned</div>
          <p className="lab-entry-text">{entry.notes}</p>
        </div>
      )}
      {entry.links?.length > 0 && (
        <div className="lab-entry-links">
          {entry.links.map((l, i) => (
            <a key={i} href={safeHref(l)} target="_blank" rel="noopener noreferrer">
              {l.replace(/^https?:\/\/(www\.)?/, '').slice(0, 48)}
            </a>
          ))}
        </div>
      )}
      <SearchLinks query={entry.topics.join(' ')} compact />
    </article>
  )
}

function monthLabel(ts: number) {
  const d = new Date(ts)
  const now = new Date()
  if (d.toDateString() === now.toDateString()) return 'Today'
  return d.toLocaleDateString(undefined, d.getFullYear() === now.getFullYear() ? { month: 'long' } : { month: 'long', year: 'numeric' })
}

export default function Log() {
  const entries = useLiveQuery(() => db.lab.orderBy('createdAt').reverse().toArray(), []) as LabEntryX[] | undefined
  const [q, setQ] = useState('')
  const [starOnly, setStarOnly] = useState(false)

  const filtered = useMemo(() => {
    const needle = q.trim().toLowerCase()
    return (entries ?? []).filter((e) => {
      if (starOnly && !e.starred) return false
      if (!needle) return true
      const hay = [...e.topics, e.connection ?? '', e.notes ?? '', e.prompt ?? '', ...(e.links ?? [])].join(' ').toLowerCase()
      return hay.includes(needle)
    })
  }, [entries, q, starOnly])

  const groups = useMemo(() => {
    const out: { label: string; items: LabEntryX[] }[] = []
    for (const e of filtered) {
      const label = monthLabel(e.createdAt)
      const last = out[out.length - 1]
      if (last && last.label === label) last.items.push(e)
      else out.push({ label, items: [e] })
    }
    return out
  }, [filtered])

  if (!entries) return <div className="empty">Loading the log…</div>

  return (
    <div className="stack">
      <div className="lab-log-bar">
        <input
          className="input lab-search-input"
          type="search"
          placeholder="Search topics, connections, notes"
          value={q}
          onChange={(e) => setQ(e.target.value)}
        />
        <button className={`btn lab-star${starOnly ? ' on' : ''}`} onClick={() => setStarOnly((s) => !s)} aria-pressed={starOnly}>
          {starOnly ? '★' : '☆'} Starred
        </button>
      </div>
      <div className="lab-count">
        {filtered.length} of {entries.length} entr{entries.length === 1 ? 'y' : 'ies'}
      </div>
      {entries.length === 0 ? (
        <div className="empty">Nothing logged yet. Spin something strange and write down what you find.</div>
      ) : filtered.length === 0 ? (
        <div className="empty">No entries match.</div>
      ) : (
        <div className="lab-groups">
          {groups.map((g) => (
            <section key={g.label} className="lab-group">
              <h3 className="lab-group-title">{g.label}</h3>
              <div className="lab-list">
                {g.items.map((e) => (
                  <EntryCard key={e.id} entry={e} onTopic={setQ} />
                ))}
              </div>
            </section>
          ))}
        </div>
      )}
    </div>
  )
}

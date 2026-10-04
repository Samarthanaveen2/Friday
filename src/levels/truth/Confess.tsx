import { useMemo, useState } from 'react'
import { useLiveQuery } from 'dexie-react-hooks'
import { db } from '../../db/db'
import type { TruthKind, TruthStatus } from '../../db/types'
import { ACKS, KIND_HINT, KIND_LABEL, PROMPTS, STATUS_HINT, STATUS_LABEL, type TruthEntry, parseTags, pick } from './content'

const KINDS: TruthKind[] = ['lie', 'avoided', 'self']
const STATUSES: TruthStatus[] = ['confessed', 'addressed', 'pattern']

function topCounts(values: (string | undefined)[], limit = 50): string[] {
  const m = new Map<string, { label: string; n: number }>()
  for (const v of values) {
    const t = v?.trim()
    if (!t) continue
    const k = t.toLowerCase()
    const cur = m.get(k)
    if (cur) cur.n++
    else m.set(k, { label: t, n: 1 })
  }
  return [...m.values()].sort((a, b) => b.n - a.n).slice(0, limit).map((x) => x.label)
}

export default function Confess() {
  const past = useLiveQuery(() => db.truths.toArray() as Promise<TruthEntry[]>, [])
  const [promptIdx, setPromptIdx] = useState(() => Math.floor(Math.random() * PROMPTS.length))
  const [text, setText] = useState('')
  const [kind, setKind] = useState<TruthKind>('avoided')
  const [who, setWho] = useState('')
  const [topic, setTopic] = useState('')
  const [tags, setTags] = useState('')
  const [status, setStatus] = useState<TruthStatus>('confessed')
  const [more, setMore] = useState(false)
  const [ritual, setRitual] = useState<{ ack: string; n: number } | null>(null)
  const [saving, setSaving] = useState(false)

  const whoOptions = useMemo(() => topCounts((past ?? []).map((t) => t.who)), [past])
  const topicOptions = useMemo(() => topCounts((past ?? []).map((t) => t.topic)), [past])
  const tagOptions = useMemo(() => topCounts((past ?? []).flatMap((t) => t.tags ?? []), 12), [past])
  const currentTags = parseTags(tags)

  const prompt = PROMPTS[promptIdx]
  const nextPrompt = () => setPromptIdx((i) => (i + 1 + Math.floor(Math.random() * (PROMPTS.length - 1))) % PROMPTS.length)

  const toggleTag = (t: string) => {
    const has = currentTags.includes(t)
    setTags((has ? currentTags.filter((x) => x !== t) : [...currentTags, t]).join(', '))
  }

  const submit = async () => {
    const body = text.trim()
    if (!body || saving) return
    setSaving(true)
    const now = Date.now()
    const entry: TruthEntry = {
      createdAt: now,
      text: body,
      kind,
      who: who.trim() || undefined,
      topic: topic.trim() || undefined,
      status,
      tags: currentTags,
      prompt,
      ...(status === 'addressed' ? { addressedAt: now } : {}),
      ...(status === 'pattern' ? { patternAt: now } : {}),
    }
    try {
      await db.truths.add(entry)
      setRitual({ ack: pick(ACKS, ritual?.ack), n: (ritual?.n ?? 0) + 1 })
      setText('')
      setWho('')
      setTopic('')
      setTags('')
      setStatus('confessed')
      nextPrompt()
    } finally {
      setSaving(false)
    }
  }

  return (
    <div className="stack truth-confess">
      <section className="panel truth-write">
        <div className="truth-prompt-row">
          <p key={promptIdx} className="truth-prompt">
            {prompt}
          </p>
          <button type="button" className="truth-text-btn" onClick={nextPrompt} aria-label="Show another prompt">
            Shuffle
          </button>
        </div>
        <label className="truth-visually-hidden" htmlFor="truth-text">
          The truth
        </label>
        <textarea
          id="truth-text"
          className="truth-textarea"
          placeholder="Write it plainly. No one else is reading."
          value={text}
          onChange={(e) => setText(e.target.value)}
          onKeyDown={(e) => {
            if (e.key === 'Enter' && (e.metaKey || e.ctrlKey)) submit()
          }}
        />
        <div className="truth-write-foot">
          <span className="truth-hint truth-hide-sm">⌘ or Ctrl + Enter</span>
          <span className="spacer" />
          <button type="button" className="btn truth-btn-primary truth-say" onClick={submit} disabled={!text.trim() || saving}>
            Say it
          </button>
        </div>
      </section>

      {ritual && (
        <div key={ritual.n} className="truth-said" role="status">
          <span className="truth-said-check" aria-hidden>
            <svg viewBox="0 0 24 24" width="16" height="16" fill="none" stroke="currentColor" strokeWidth="2.6" strokeLinecap="round" strokeLinejoin="round">
              <path d="M5 12.5l4.5 4.5L19 7.5" pathLength={1} />
            </svg>
          </span>
          <div className="truth-said-text">
            <div className="truth-said-title">Saved</div>
            <div className="truth-said-ack">{ritual.ack}</div>
          </div>
          <button type="button" className="truth-text-btn truth-said-close" onClick={() => setRitual(null)} aria-label="Dismiss">
            Done
          </button>
        </div>
      )}

      <div>
        <div className="truth-section-title">What kind?</div>
        <div className="truth-seg" role="radiogroup" aria-label="What kind">
          {KINDS.map((k) => (
            <button key={k} type="button" role="radio" aria-checked={kind === k} className={`truth-seg-btn ${kind === k ? 'active' : ''}`} onClick={() => setKind(k)}>
              {KIND_LABEL[k]}
            </button>
          ))}
        </div>
        <div className="truth-footnote">{KIND_HINT[kind]}</div>
      </div>

      <div>
        <div className="truth-section-title">Details</div>
        <div className="truth-group">
          <label className="truth-row truth-field" htmlFor="truth-who">
            <span className="truth-row-label">Who</span>
            <input
              id="truth-who"
              className="truth-row-input"
              list="truth-who-list"
              placeholder="A person, or “me”"
              value={who}
              onChange={(e) => setWho(e.target.value)}
              autoComplete="off"
            />
          </label>
          <datalist id="truth-who-list">
            {whoOptions.map((w) => (
              <option key={w} value={w} />
            ))}
          </datalist>
          <label className="truth-row truth-field" htmlFor="truth-topic">
            <span className="truth-row-label">Topic</span>
            <input
              id="truth-topic"
              className="truth-row-input"
              list="truth-topic-list"
              placeholder="Work, money, health…"
              value={topic}
              onChange={(e) => setTopic(e.target.value)}
              autoComplete="off"
            />
          </label>
          <datalist id="truth-topic-list">
            {topicOptions.map((w) => (
              <option key={w} value={w} />
            ))}
          </datalist>
          <label className="truth-row truth-field" htmlFor="truth-tags">
            <span className="truth-row-label">Tags</span>
            <input id="truth-tags" className="truth-row-input" placeholder="fear, approval…" value={tags} onChange={(e) => setTags(e.target.value)} autoComplete="off" />
          </label>
          {more && (
            <div className="truth-row truth-field truth-status-row">
              <span className="truth-row-label">Status</span>
              <div className="truth-seg truth-seg-sm" role="radiogroup" aria-label="Status">
                {STATUSES.map((s) => (
                  <button key={s} type="button" role="radio" aria-checked={status === s} className={`truth-seg-btn ${status === s ? 'active' : ''}`} onClick={() => setStatus(s)} title={STATUS_HINT[s]}>
                    {STATUS_LABEL[s]}
                  </button>
                ))}
              </div>
            </div>
          )}
        </div>
        {tagOptions.length > 0 && (
          <div className="truth-tag-suggest">
            {tagOptions.map((t) => (
              <button key={t} type="button" className={`chip truth-chip-btn ${currentTags.includes(t) ? 'active' : ''}`} onClick={() => toggleTag(t)}>
                #{t}
              </button>
            ))}
          </div>
        )}
        <div className="truth-footnote">
          {more ? (
            STATUS_HINT[status]
          ) : (
            <button type="button" className="truth-text-btn" onClick={() => setMore(true)}>
              Set a status
            </button>
          )}
        </div>
      </div>
    </div>
  )
}

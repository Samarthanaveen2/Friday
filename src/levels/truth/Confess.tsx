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
    <div className="stack">
      <section className="panel truth-panel truth-prompt-panel">
        <div className="row-between">
          <div className="panel-title" style={{ marginBottom: 0 }}>
            Courage prompt
          </div>
          <button type="button" className="btn btn-ghost btn-sm" onClick={nextPrompt} aria-label="Another prompt">
            ↻ Another
          </button>
        </div>
        <p key={promptIdx} className="truth-prompt">
          {prompt}
        </p>
      </section>

      {ritual && (
        <div key={ritual.n} className="truth-ritual" role="status">
          <div className="truth-ritual-mark" aria-hidden>
            <span className="truth-ritual-ring" />
            <span className="truth-ritual-core" />
          </div>
          <div>
            <div className="truth-ritual-said mono">Said it.</div>
            <div className="truth-ritual-ack">{ritual.ack}</div>
          </div>
          <button type="button" className="btn btn-ghost btn-sm truth-ritual-close" onClick={() => setRitual(null)} aria-label="Dismiss">
            ✕
          </button>
        </div>
      )}

      <section className="panel truth-panel">
        <div className="stack">
          <div>
            <label className="label" htmlFor="truth-text">
              The truth
            </label>
            <textarea
              id="truth-text"
              className="textarea truth-textarea"
              placeholder="Write it plainly. No one else is reading."
              value={text}
              onChange={(e) => setText(e.target.value)}
              onKeyDown={(e) => {
                if (e.key === 'Enter' && (e.metaKey || e.ctrlKey)) submit()
              }}
            />
          </div>

          <div>
            <span className="label">What kind?</span>
            <div className="truth-seg" role="radiogroup">
              {KINDS.map((k) => (
                <button
                  key={k}
                  type="button"
                  role="radio"
                  aria-checked={kind === k}
                  className={`truth-seg-btn ${kind === k ? 'active' : ''}`}
                  onClick={() => setKind(k)}
                >
                  <span className="truth-seg-name">{KIND_LABEL[k]}</span>
                  <span className="truth-seg-hint">{KIND_HINT[k]}</span>
                </button>
              ))}
            </div>
          </div>

          <div className="truth-fields">
            <div>
              <label className="label" htmlFor="truth-who">
                Who <span className="truth-optional">optional</span>
              </label>
              <input
                id="truth-who"
                className="input"
                list="truth-who-list"
                placeholder="A person — or “me”"
                value={who}
                onChange={(e) => setWho(e.target.value)}
                autoComplete="off"
              />
              <datalist id="truth-who-list">
                {whoOptions.map((w) => (
                  <option key={w} value={w} />
                ))}
              </datalist>
            </div>
            <div>
              <label className="label" htmlFor="truth-topic">
                Topic <span className="truth-optional">optional</span>
              </label>
              <input
                id="truth-topic"
                className="input"
                list="truth-topic-list"
                placeholder="Work, money, health…"
                value={topic}
                onChange={(e) => setTopic(e.target.value)}
                autoComplete="off"
              />
              <datalist id="truth-topic-list">
                {topicOptions.map((w) => (
                  <option key={w} value={w} />
                ))}
              </datalist>
            </div>
          </div>

          {!more ? (
            <button type="button" className="btn btn-ghost btn-sm truth-more" onClick={() => setMore(true)}>
              + Tags & status
            </button>
          ) : (
            <>
              <div>
                <label className="label" htmlFor="truth-tags">
                  Tags <span className="truth-optional">comma separated</span>
                </label>
                <input id="truth-tags" className="input" placeholder="fear, approval, procrastination" value={tags} onChange={(e) => setTags(e.target.value)} />
                {tagOptions.length > 0 && (
                  <div className="row truth-tag-suggest">
                    {tagOptions.map((t) => (
                      <button key={t} type="button" className={`chip truth-chip-btn ${currentTags.includes(t) ? 'truth-chip-on' : ''}`} onClick={() => toggleTag(t)}>
                        #{t}
                      </button>
                    ))}
                  </div>
                )}
              </div>
              <div>
                <span className="label">Status</span>
                <div className="row">
                  {STATUSES.map((s) => (
                    <button
                      key={s}
                      type="button"
                      className={`chip truth-chip-btn truth-status-${s} ${status === s ? 'truth-chip-on' : ''}`}
                      onClick={() => setStatus(s)}
                      title={STATUS_HINT[s]}
                    >
                      {STATUS_LABEL[s]}
                    </button>
                  ))}
                </div>
                <div className="muted small" style={{ marginTop: 6 }}>
                  {STATUS_HINT[status]}
                </div>
              </div>
            </>
          )}

          <div className="row-between">
            <span className="muted small truth-hide-sm">Ctrl/⌘ + Enter to say it</span>
            <button type="button" className="btn truth-btn-red truth-say" onClick={submit} disabled={!text.trim() || saving}>
              Say it
            </button>
          </div>
        </div>
      </section>
    </div>
  )
}

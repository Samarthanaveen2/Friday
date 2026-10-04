import { useState } from 'react'
import { db } from '../../db/db'
import { addDays, dayKey, fromDayKey, weekStart } from '../../lib/date'
import type { DoneIndex, ExperimentResult, ForgeHabit, ForgeReview } from './stats'

type Field = 'broke' | 'why' | 'fix'

const PROMPTS: Record<Field, { title: string; prompts: string[] }> = {
  broke: {
    title: 'What broke',
    prompts: [
      'Where did the plan meet reality and lose?',
      'Which day felt hardest, and what was going on around it?',
      'What did you skip, delay, or quietly avoid?',
      'Where did you drift from the person you’re voting for?',
    ],
  },
  why: {
    title: 'Why it broke',
    prompts: [
      'Was it the cue, the effort, the timing, or the mood?',
      'What was true about your energy, sleep, or surroundings?',
      'If a kind friend described this week, what would they say caused it?',
      'What made the wrong thing easy and the right thing hard?',
    ],
  },
  fix: {
    title: 'One fix for next week',
    prompts: [
      'One small change to the plan or environment. Not “try harder”.',
      'Write it as: If ___, then I will ___.',
      'What would make the right thing the easy thing?',
      'What can you set up tonight so Future You barely has to decide?',
    ],
  },
}

const RESULTS: { key: ExperimentResult; label: string }[] = [
  { key: 'worked', label: 'It helped' },
  { key: 'partly', label: 'Partly' },
  { key: 'didnt', label: 'Didn’t fit, adjust it' },
]

function hash(s: string) {
  let h = 0
  for (const c of s) h = (h * 31 + c.charCodeAt(0)) | 0
  return Math.abs(h)
}

function weekLabel(ws: string) {
  const a = fromDayKey(ws)
  const b = fromDayKey(addDays(ws, 6))
  const fmt = (d: Date) => d.toLocaleDateString(undefined, { month: 'short', day: 'numeric' })
  return `${fmt(a)} – ${fmt(b)}`
}

function ReviewForm({ week, existing }: { week: string; existing?: ForgeReview }) {
  const [draft, setDraft] = useState({ broke: existing?.broke ?? '', why: existing?.why ?? '', fix: existing?.fix ?? '' })
  const [turn, setTurn] = useState<Record<Field, number>>(() => {
    const h = hash(week)
    return { broke: h, why: h >> 3, fix: h >> 6 }
  })
  const [saved, setSaved] = useState(false)
  const dirty =
    draft.broke !== (existing?.broke ?? '') || draft.why !== (existing?.why ?? '') || draft.fix !== (existing?.fix ?? '')
  const hasAny = draft.broke.trim() || draft.why.trim() || draft.fix.trim()

  async function save() {
    const fields = { broke: draft.broke.trim(), why: draft.why.trim(), fix: draft.fix.trim(), updatedAt: Date.now() }
    if (existing?.id != null) await db.reviews.update(existing.id, fields)
    else await db.reviews.add({ weekStart: week, createdAt: Date.now(), ...fields } as ForgeReview)
    setSaved(true)
    window.setTimeout(() => setSaved(false), 2200)
  }

  return (
    <div className="stack-sm">
      <div className="forge-group">
        {(Object.keys(PROMPTS) as Field[]).map((f) => {
          const p = PROMPTS[f]
          const prompt = p.prompts[turn[f] % p.prompts.length]
          return (
            <div key={f} className="forge-field-stack">
              <div className="forge-field-head">
                <label className="forge-field-label" htmlFor={`forge-rv-${f}`}>{p.title}</label>
                <button
                  type="button"
                  className="forge-link"
                  onClick={() => setTurn({ ...turn, [f]: turn[f] + 1 })}
                  title="Show a different prompt"
                >
                  Another prompt
                </button>
              </div>
              <textarea
                id={`forge-rv-${f}`}
                className="forge-textarea"
                placeholder={prompt}
                value={draft[f]}
                rows={f === 'fix' ? 2 : 3}
                onChange={(e) => setDraft({ ...draft, [f]: e.target.value })}
              />
            </div>
          )
        })}
      </div>
      <div className="row forge-actions">
        <button className="btn btn-gold" disabled={!hasAny || !dirty} onClick={save}>
          {existing ? 'Update breakdown' : 'Save breakdown'}
        </button>
        {saved && <span className="forge-saved small">Saved. Your fix becomes next week's experiment.</span>}
        {!saved && existing && !dirty && <span className="muted small">Saved for this week. Edit any time.</span>}
      </div>
    </div>
  )
}

export default function ReviewTab({ reviews, habits, idx }: { reviews: ForgeReview[]; habits: ForgeHabit[]; idx: DoneIndex }) {
  const today = dayKey()
  const week = weekStart(today)
  const current = reviews.find((r) => r.weekStart === week)
  const previous = reviews
    .filter((r) => r.weekStart < week && r.fix?.trim())
    .sort((a, b) => b.weekStart.localeCompare(a.weekStart))[0]
  const past = reviews.filter((r) => r.weekStart < week).sort((a, b) => b.weekStart.localeCompare(a.weekStart))
  const fromLastWeek = previous?.weekStart === addDays(week, -7)

  // This week's votes so far, as context (not a grade).
  const active = habits.filter((h) => !h.archived)
  let cast = 0
  let possible = 0
  for (let k = week; k <= today; k = addDays(k, 1)) {
    for (const h of active) {
      possible++
      if (idx.get(h.id!)?.has(k)) cast++
    }
  }

  async function setResult(result: ExperimentResult) {
    const next = current?.experimentResult === result ? undefined : result
    if (current?.id != null) await db.reviews.update(current.id, { experimentResult: next } as Partial<ForgeReview>)
    else await db.reviews.add({ weekStart: week, broke: '', why: '', fix: '', createdAt: Date.now(), experimentResult: next } as ForgeReview)
  }

  return (
    <div className="grid-2 forge-review">
      <div className="stack">
        {previous ? (
          <section className="panel forge-experiment-panel">
            <div className="forge-experiment-tag">
              {fromLastWeek ? 'This week’s experiment' : `Experiment from ${weekLabel(previous.weekStart)}`}
            </div>
            <p className="forge-experiment-big">{previous.fix}</p>
            <div className="forge-result">
              <span className="muted small">How is it going?</span>
              <div className="forge-presets">
                {RESULTS.map((r) => (
                  <button
                    key={r.key}
                    className={`chip forge-chip ${current?.experimentResult === r.key ? 'active' : ''}`}
                    onClick={() => setResult(r.key)}
                  >
                    {r.label}
                  </button>
                ))}
              </div>
            </div>
          </section>
        ) : (
          <section className="panel">
            <div className="panel-title forge-tight">This week's experiment</div>
            <p className="muted small">
              Nothing yet. The fix you write below becomes next week's experiment and shows up here.
            </p>
          </section>
        )}

        <section>
          <div className="forge-section-head">
            <span>Weekly breakdown</span>
            <span className="mono">{weekLabel(week)}</span>
          </div>
          <p className="forge-footnote forge-intro">
            A rough week is information, not a verdict. Systems break and you redesign them.
            {possible > 0 && (
              <>
                {' '}
                So far this week: <span className="mono">{cast} of {possible}</span> check-ins.
              </>
            )}
          </p>
          <ReviewForm key={week} week={week} existing={current} />

        </section>
      </div>

      <section>
        <div className="forge-section-head">
          <span>Past breakdowns</span>
        </div>
        {past.length === 0 ? (
          <div className="empty forge-empty-sm">Past weeks will appear here.</div>
        ) : (
          <ul className="forge-group">
            {past.map((r) => (
              <li key={r.id}>
                <details className="forge-past-item">
                  <summary>
                    <span className="forge-past-text">
                      <span className="forge-past-week mono">{weekLabel(r.weekStart)}</span>
                      <span className="forge-past-fix">{r.fix || <span className="muted">No fix written</span>}</span>
                    </span>
                    <span className="forge-chevron" aria-hidden />
                  </summary>
                  <dl className="forge-past-body">
                    {r.broke && (<><dt>What broke</dt><dd>{r.broke}</dd></>)}
                    {r.why && (<><dt>Why</dt><dd>{r.why}</dd></>)}
                    {r.fix && (<><dt>Fix</dt><dd>{r.fix}</dd></>)}
                    {r.experimentResult && (
                      <>
                        <dt>Previous experiment</dt>
                        <dd>{RESULTS.find((x) => x.key === r.experimentResult)?.label}</dd>
                      </>
                    )}
                  </dl>
                </details>
              </li>
            ))}
          </ul>
        )}
      </section>
    </div>
  )
}

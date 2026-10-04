import { useState } from 'react'
import { db } from '../../db/db'
import { PRESETS, SOFT_CAP, defaultTiny, type DoneIndex, type ForgeHabit } from './stats'

const IDENTITY_PREFIX = 'I am someone who '

interface Draft {
  name: string
  identity: string
  tiny: string
}

const blank: Draft = { name: '', identity: IDENTITY_PREFIX, tiny: '' }

function HabitForm({
  initial,
  activeCount,
  editing,
  onDone,
}: {
  initial: Draft
  activeCount: number
  editing?: ForgeHabit
  onDone: () => void
}) {
  const [d, setD] = useState<Draft>(initial)
  const overCap = !editing && activeCount >= SOFT_CAP
  const identityOk = d.identity.trim().length > 0 && d.identity.trim() !== IDENTITY_PREFIX.trim()
  const canSave = d.name.trim().length > 0 && identityOk

  async function save() {
    if (!canSave) return
    const fields = { name: d.name.trim(), identity: d.identity.trim(), tiny: d.tiny.trim() || undefined }
    if (editing?.id != null) await db.habits.update(editing.id, fields)
    else await db.habits.add({ ...fields, createdAt: Date.now(), archived: false } as ForgeHabit)
    setD(blank)
    onDone()
  }

  const uid = editing?.id ?? 'new'
  return (
    <div className="stack-sm">
      {!editing && (
        <div className="forge-preset-wrap">
          <div className="forge-presets">
            {PRESETS.map((p) => (
              <button
                key={p.name}
                type="button"
                className={`chip forge-chip ${d.name === p.name ? 'active' : ''}`}
                onClick={() => setD({ name: p.name, identity: p.identity, tiny: p.tiny })}
              >
                {p.name}
              </button>
            ))}
          </div>
        </div>
      )}

      <div className="forge-group">
        <div className="forge-field">
          <label htmlFor={`forge-name-${uid}`}>Habit</label>
          <input
            id={`forge-name-${uid}`}
            className="forge-field-input"
            placeholder="Read 10 pages"
            value={d.name}
            maxLength={60}
            onChange={(e) => setD({ ...d, name: e.target.value })}
          />
        </div>
        <div className="forge-field">
          <label htmlFor={`forge-identity-${uid}`}>Identity</label>
          <input
            id={`forge-identity-${uid}`}
            className="forge-field-input"
            placeholder="I am a reader"
            value={d.identity}
            maxLength={90}
            onChange={(e) => setD({ ...d, identity: e.target.value })}
          />
        </div>
        <div className="forge-field">
          <label htmlFor={`forge-tiny-${uid}`}>Minimum</label>
          <input
            id={`forge-tiny-${uid}`}
            className="forge-field-input"
            placeholder={defaultTiny(d.name || 'it')}
            value={d.tiny}
            maxLength={60}
            onChange={(e) => setD({ ...d, tiny: e.target.value })}
          />
        </div>
      </div>
      <p className="forge-footnote">
        The identity is who each check-in makes you. The minimum is a two-minute version for hard days, small enough to feel silly.
      </p>

      {overCap && (
        <div className="forge-warn">
          <strong>You already have {activeCount} habits.</strong> A few habits you actually keep beat many you drop.
          Consider archiving one first, or add this anyway if you're sure.
        </div>
      )}

      <div className="row forge-actions">
        <button className="btn btn-gold" disabled={!canSave} onClick={save}>
          {editing ? 'Save changes' : overCap ? 'Add anyway' : 'Add habit'}
        </button>
        {(editing || d.name) && (
          <button className="btn btn-ghost forge-ghost" onClick={() => { setD(blank); onDone() }}>
            Cancel
          </button>
        )}
      </div>
    </div>
  )
}

export default function HabitsTab({ habits, idx }: { habits: ForgeHabit[]; idx: DoneIndex }) {
  const [editingId, setEditingId] = useState<number | null>(null)
  const [formKey, setFormKey] = useState(0)
  const active = habits.filter((h) => !h.archived)
  const archived = habits.filter((h) => h.archived)

  async function archive(h: ForgeHabit) {
    await db.habits.update(h.id!, { archived: true, archivedAt: Date.now() } as Partial<ForgeHabit>)
  }
  async function restore(h: ForgeHabit) {
    if (active.length >= SOFT_CAP && !window.confirm(`You have ${active.length} active habits. Restore anyway? Fewer, kept habits usually win.`)) return
    await db.habits.update(h.id!, { archived: false })
  }
  async function remove(h: ForgeHabit) {
    const votes = idx.get(h.id!)?.size ?? 0
    if (!window.confirm(`Permanently delete "${h.name}" and its ${votes} check-ins? Archiving keeps the history.`)) return
    await db.transaction('rw', db.habits, db.habitLogs, async () => {
      await db.habitLogs.where('habitId').equals(h.id!).delete()
      await db.habits.delete(h.id!)
    })
  }

  return (
    <div className="grid-2 forge-habits">
      <section>
        <div className="forge-section-head">
          <span>New habit</span>
        </div>
        <HabitForm key={formKey} initial={blank} activeCount={active.length} onDone={() => setFormKey((k) => k + 1)} />
      </section>

      <div className="stack">
        <section>
          <div className="forge-section-head">
            <span>Active</span>
            <span className={`forge-cap ${active.length > SOFT_CAP ? 'over' : ''}`}>
              {active.length} of {SOFT_CAP}
            </span>
          </div>
          {active.length === 0 ? (
            <div className="empty forge-empty-sm">No habits yet. One is plenty to start.</div>
          ) : (
            <ul className="forge-group">
              {active.map((h) =>
                editingId === h.id ? (
                  <li key={h.id} className="forge-list-item editing">
                    <HabitForm
                      initial={{ name: h.name, identity: h.identity, tiny: h.tiny ?? '' }}
                      activeCount={active.length}
                      editing={h}
                      onDone={() => setEditingId(null)}
                    />
                  </li>
                ) : (
                  <li key={h.id} className="forge-list-item">
                    <div className="forge-list-main">
                      <div className="forge-habit-name">{h.name}</div>
                      <div className="forge-identity">{h.identity}</div>
                      {h.tiny && <div className="forge-faint small">Minimum: {h.tiny}</div>}
                    </div>
                    <div className="forge-list-actions">
                      <button className="btn btn-sm forge-btn-tint" onClick={() => setEditingId(h.id!)}>Edit</button>
                      <button className="btn btn-sm btn-ghost forge-ghost" onClick={() => archive(h)}>Archive</button>
                    </div>
                  </li>
                ),
              )}
            </ul>
          )}
          {active.length > SOFT_CAP && (
            <p className="forge-footnote">Above the suggested limit. That's allowed. If check-ins start to feel heavy, archive the least important one. Its history is kept.</p>
          )}
        </section>

        {archived.length > 0 && (
          <section>
            <div className="forge-section-head">
              <span>Archived</span>
              <span>History kept</span>
            </div>
            <ul className="forge-group">
              {archived.map((h) => (
                <li key={h.id} className="forge-list-item muted-item">
                  <div className="forge-list-main">
                    <div className="forge-habit-name">{h.name}</div>
                    <div className="muted small">
                      {h.identity} · {idx.get(h.id!)?.size ?? 0} check-ins
                    </div>
                  </div>
                  <div className="forge-list-actions">
                    <button className="btn btn-sm forge-btn-tint" onClick={() => restore(h)}>Restore</button>
                    <button className="btn btn-sm btn-ghost btn-danger" onClick={() => remove(h)}>Delete</button>
                  </div>
                </li>
              ))}
            </ul>
          </section>
        )}
      </div>
    </div>
  )
}

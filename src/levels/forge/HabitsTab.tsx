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

  return (
    <div className="stack">
      {!editing && (
        <div>
          <span className="label">Start from a preset</span>
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

      <div>
        <label className="label" htmlFor="forge-name">Habit (the action)</label>
        <input
          id="forge-name"
          className="input forge-input"
          placeholder="Read 10 pages"
          value={d.name}
          maxLength={60}
          onChange={(e) => setD({ ...d, name: e.target.value })}
        />
      </div>
      <div>
        <label className="label" htmlFor="forge-identity">Identity (who each vote makes you)</label>
        <input
          id="forge-identity"
          className="input forge-input"
          placeholder="I am a reader"
          value={d.identity}
          maxLength={90}
          onChange={(e) => setD({ ...d, identity: e.target.value })}
        />
        <p className="muted small forge-hint">Every time you do it, you cast a vote for this person. You don't need a majority of perfect days, just more votes than yesterday.</p>
      </div>
      <div>
        <label className="label" htmlFor="forge-tiny">Minimum version (for hard days)</label>
        <input
          id="forge-tiny"
          className="input forge-input"
          placeholder={defaultTiny(d.name || 'it')}
          value={d.tiny}
          maxLength={60}
          onChange={(e) => setD({ ...d, tiny: e.target.value })}
        />
        <p className="muted small forge-hint">Two minutes or less. So small it feels silly. This is what keeps the chain warm.</p>
      </div>

      {overCap && (
        <div className="forge-warn">
          <strong>You already have {activeCount} keystone habits.</strong> A few habits you actually keep beat many you drop.
          Consider archiving one first, or add this anyway if you're sure.
        </div>
      )}

      <div className="row">
        <button className="btn forge-btn-primary" disabled={!canSave} onClick={save}>
          {editing ? 'Save changes' : overCap ? 'Add anyway' : 'Forge this habit'}
        </button>
        {(editing || d.name) && (
          <button className="btn btn-ghost" onClick={() => { setD(blank); onDone() }}>
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
    if (!window.confirm(`Permanently delete "${h.name}" and its ${votes} votes? Archiving keeps the history.`)) return
    await db.transaction('rw', db.habits, db.habitLogs, async () => {
      await db.habitLogs.where('habitId').equals(h.id!).delete()
      await db.habits.delete(h.id!)
    })
  }

  return (
    <div className="grid-2 forge-habits">
      <section className="panel forge-panel">
        <div className="panel-title">New keystone habit</div>
        <HabitForm key={formKey} initial={blank} activeCount={active.length} onDone={() => setFormKey((k) => k + 1)} />
      </section>

      <div className="stack">
        <section className="panel forge-panel">
          <div className="row-between">
            <div className="panel-title">Active</div>
            <span className={`forge-cap ${active.length > SOFT_CAP ? 'over' : ''}`}>
              {active.length} / {SOFT_CAP}
            </span>
          </div>
          {active.length === 0 ? (
            <div className="empty">The anvil is empty. Pick one habit to start. One is plenty.</div>
          ) : (
            <ul className="forge-list">
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
                      <div className="forge-identity small">{h.identity}</div>
                      {h.tiny && <div className="muted small">Minimum: {h.tiny}</div>}
                    </div>
                    <div className="row forge-list-actions">
                      <button className="btn btn-sm" onClick={() => setEditingId(h.id!)}>Edit</button>
                      <button className="btn btn-sm btn-ghost" onClick={() => archive(h)}>Archive</button>
                    </div>
                  </li>
                ),
              )}
            </ul>
          )}
          {active.length > SOFT_CAP && (
            <p className="muted small forge-hint">Above the soft cap. That's allowed. If check-ins start feeling heavy, archive the least important one. Its votes are kept.</p>
          )}
        </section>

        {archived.length > 0 && (
          <section className="panel forge-panel">
            <div className="panel-title">Archived · history kept</div>
            <ul className="forge-list">
              {archived.map((h) => (
                <li key={h.id} className="forge-list-item muted-item">
                  <div className="forge-list-main">
                    <div className="forge-habit-name">{h.name}</div>
                    <div className="muted small">
                      {h.identity} · {idx.get(h.id!)?.size ?? 0} votes
                    </div>
                  </div>
                  <div className="row forge-list-actions">
                    <button className="btn btn-sm" onClick={() => restore(h)}>Restore</button>
                    <button className="btn btn-sm btn-danger" onClick={() => remove(h)}>Delete</button>
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

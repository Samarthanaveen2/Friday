import { useEffect, useMemo, useState } from 'react'
import { useLiveQuery } from 'dexie-react-hooks'
import LevelHeader from '../../components/LevelHeader'
import { db } from '../../db/db'
import { addDays, dayKey, weekStart } from '../../lib/date'
import HabitsTab from './HabitsTab'
import Heatmap from './Heatmap'
import ReviewTab from './ReviewTab'
import TodayTab from './TodayTab'
import { indexLogs, type ForgeHabit, type ForgeLog, type ForgeReview } from './stats'
import './forge.css'

type Tab = 'today' | 'heat' | 'review' | 'habits'

const TABS: { key: Tab; label: string }[] = [
  { key: 'today', label: 'Today' },
  { key: 'heat', label: 'Heatmap' },
  { key: 'review', label: 'Breakdown' },
  { key: 'habits', label: 'Habits' },
]

const TAB_KEY = 'forge.tab'

function readTab(): Tab {
  try {
    const t = localStorage.getItem(TAB_KEY) as Tab | null
    if (t && TABS.some((x) => x.key === t)) return t
  } catch {
    /* storage unavailable */
  }
  return 'today'
}

export default function Forge() {
  const [tab, setTab] = useState<Tab>(readTab)
  const habits = useLiveQuery(() => db.habits.orderBy('createdAt').toArray() as Promise<ForgeHabit[]>, [])
  const logs = useLiveQuery(() => db.habitLogs.toArray() as Promise<ForgeLog[]>, [])
  const reviews = useLiveQuery(() => db.reviews.toArray() as Promise<ForgeReview[]>, [])
  const idx = useMemo(() => indexLogs(logs ?? []), [logs])

  useEffect(() => {
    try {
      localStorage.setItem(TAB_KEY, tab)
    } catch {
      /* ignore */
    }
  }, [tab])

  const loading = !habits || !logs || !reviews
  const active = habits?.filter((h) => !h.archived) ?? []
  const today = dayKey()
  const doneToday = active.filter((h) => idx.get(h.id!)?.has(today)).length

  const week = weekStart(today)
  const experiment = reviews
    ?.filter((r) => r.weekStart < week && r.fix?.trim())
    .sort((a, b) => b.weekStart.localeCompare(a.weekStart))
    .find((r) => r.weekStart >= addDays(week, -7))?.fix

  const summary =
    active.length > 0 ? (
      <div className="forge-summary" title="Identity votes cast today">
        <span className="forge-summary-n mono">
          {doneToday}
          <span className="muted">/{active.length}</span>
        </span>
        <span className="forge-summary-l">votes today</span>
      </div>
    ) : undefined

  return (
    <div className="forge">
      <LevelHeader path="/forge" right={summary} />

      <nav className="forge-tabs" role="tablist" aria-label="Forge sections">
        {TABS.map((t) => (
          <button
            key={t.key}
            role="tab"
            aria-selected={tab === t.key}
            className={`forge-tab ${tab === t.key ? 'active' : ''}`}
            onClick={() => setTab(t.key)}
          >
            {t.label}
          </button>
        ))}
      </nav>

      {loading ? (
        <div className="empty">Heating the forge…</div>
      ) : tab === 'today' ? (
        <TodayTab habits={habits} idx={idx} logs={logs} experiment={experiment} onAddHabit={() => setTab('habits')} />
      ) : tab === 'heat' ? (
        <Heatmap habits={habits} idx={idx} />
      ) : tab === 'review' ? (
        <ReviewTab reviews={reviews} habits={habits} idx={idx} />
      ) : (
        <HabitsTab habits={habits} idx={idx} />
      )}
    </div>
  )
}

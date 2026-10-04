import { useLiveQuery } from 'dexie-react-hooks'
import { NavLink, Route, Routes } from 'react-router-dom'
import LevelHeader from '../../components/LevelHeader'
import { db, getSetting } from '../../db/db'
import { dayKey } from '../../lib/date'
import History from './History'
import { Negotiation, SealedDeal } from './Today'
import { DEFAULT_RATE, type NegDeal, RATE_KEY, inheritedOwed, keepStats, keptStreak } from './logic'
import './negotiator.css'

export default function Negotiator() {
  const deals = useLiveQuery(() => db.deals.toArray() as Promise<NegDeal[]>, [])
  const rate = useLiveQuery(() => getSetting<number>(RATE_KEY, DEFAULT_RATE), [])
  const today = dayKey()
  const loading = deals === undefined || rate === undefined
  const streak = deals ? keptStreak(deals, today) : 0

  return (
    <div className="neg">
      <LevelHeader
        path="/negotiator"
        right={
          streak > 0 ? (
            <div className="neg-header-streak">
              <span className="mono neg-gold">{streak}</span>
              <span className="small muted">day kept streak</span>
            </div>
          ) : undefined
        }
      />
      <nav className="neg-tabs" aria-label="Negotiator sections">
        <NavLink end to="/negotiator" className={({ isActive }) => `neg-tab ${isActive ? 'active' : ''}`}>
          Today
        </NavLink>
        <NavLink to="/negotiator/history" className={({ isActive }) => `neg-tab ${isActive ? 'active' : ''}`}>
          History
        </NavLink>
      </nav>

      {loading ? (
        <div className="empty">Laying out the table…</div>
      ) : (
        <Routes>
          <Route index element={<TodayView deals={deals} rate={rate} today={today} />} />
          <Route path="history" element={<History deals={deals} />} />
          <Route path="*" element={<TodayView deals={deals} rate={rate} today={today} />} />
        </Routes>
      )}
    </div>
  )
}

function TodayView({ deals, rate, today }: { deals: NegDeal[]; rate: number; today: string }) {
  const todayDeal = deals.find((d) => d.date === today)
  const keepRate = keepStats(deals, today).rate
  if (todayDeal) return <SealedDeal key={todayDeal.id} deal={todayDeal} keepRate={keepRate} />
  const { owed, from, unreviewed } = inheritedOwed(deals, today)
  return <Negotiation today={today} rate={rate} owedIn={owed} owedFrom={from} unreviewed={unreviewed} keepRate={keepRate} />
}

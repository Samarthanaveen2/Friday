import { useMemo } from 'react'
import { NavLink, Route, Routes } from 'react-router-dom'
import { useLiveQuery } from 'dexie-react-hooks'
import { db } from '../db/db'
import Dares from './Dares'
import Fuel from './Fuel'
import { activeDays, streak } from './fuel'
import Generator from './Generator'
import Log from './Log'
import MindMap from './MindMap'
import type { LabEntryX } from './shared'
import { TOPICS } from './topics'
import './attic.css'

const TABS = [
  { to: '/', label: 'Spin', end: true },
  { to: '/dares', label: 'Dares', end: false },
  { to: '/fuel', label: 'Fuel', end: false },
  { to: '/log', label: 'Log', end: false },
  { to: '/map', label: 'Map', end: false },
]

export default function Attic() {
  const entries = useLiveQuery(() => db.lab.toArray(), []) as LabEntryX[] | undefined
  const dares = useLiveQuery(() => db.dares.toArray(), [])
  const days = useMemo(() => streak(activeDays(entries ?? [], dares ?? [])), [entries, dares])

  return (
    <div className="lab">
      <header className="level-header row-between">
        <div>
          <div className="level-number">Openness, overcharged</div>
          <h1 className="level-title">The Attic</h1>
          <p className="level-tagline">Climb up, open a box, let the mind run wild.</p>
        </div>
        <div className="lab-header-meta">
          <div>
            <b>{TOPICS.length.toLocaleString()}</b>
            <span>Topics</span>
          </div>
          <div>
            <b>{entries?.length ?? 0}</b>
            <span>Explored</span>
          </div>
          <div>
            <b>{days}</b>
            <span>Day streak</span>
          </div>
        </div>
      </header>
      <nav className="lab-seg lab-tabs" aria-label="Attic sections">
        {TABS.map((t) => (
          <NavLink key={t.to} to={t.to} end={t.end} className={({ isActive }) => `lab-seg-btn${isActive ? ' active' : ''}`}>
            {t.label}
          </NavLink>
        ))}
      </nav>
      <Routes>
        <Route index element={<Generator />} />
        <Route path="dares" element={<Dares />} />
        <Route path="fuel" element={<Fuel />} />
        <Route path="log" element={<Log />} />
        <Route path="map" element={<MindMap />} />
        <Route path="*" element={<Generator />} />
      </Routes>
    </div>
  )
}

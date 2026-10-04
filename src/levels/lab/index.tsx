import { NavLink, Route, Routes } from 'react-router-dom'
import { useLiveQuery } from 'dexie-react-hooks'
import LevelHeader from '../../components/LevelHeader'
import { db } from '../../db/db'
import Generator from './Generator'
import Log from './Log'
import MindMap from './MindMap'
import { TOPICS } from './topics'
import './lab.css'

const TABS = [
  { to: '/lab', label: 'Generator', glyph: '✺', end: true },
  { to: '/lab/log', label: 'Log', glyph: '❡', end: false },
  { to: '/lab/map', label: 'Mind Map', glyph: '✧', end: false },
]

export default function Lab() {
  const count = useLiveQuery(() => db.lab.count(), [])
  return (
    <div className="lab">
      <div className="lab-bg" aria-hidden>
        <span />
        <span />
        <span />
      </div>
      <LevelHeader
        path="/lab"
        right={
          <div className="lab-header-meta mono">
            <div>
              <b>{TOPICS.length}</b> topics
            </div>
            <div>
              <b>{count ?? 0}</b> explored
            </div>
          </div>
        }
      />
      <nav className="lab-tabs">
        {TABS.map((t) => (
          <NavLink key={t.to} to={t.to} end={t.end} className={({ isActive }) => `lab-tab${isActive ? ' active' : ''}`}>
            <span aria-hidden>{t.glyph}</span> {t.label}
          </NavLink>
        ))}
      </nav>
      <Routes>
        <Route index element={<Generator />} />
        <Route path="log" element={<Log />} />
        <Route path="map" element={<MindMap />} />
        <Route path="*" element={<Generator />} />
      </Routes>
    </div>
  )
}

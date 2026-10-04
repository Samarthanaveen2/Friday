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
  { to: '/lab', label: 'Generator', end: true },
  { to: '/lab/log', label: 'Log', end: false },
  { to: '/lab/map', label: 'Mind Map', end: false },
]

export default function Lab() {
  const count = useLiveQuery(() => db.lab.count(), [])
  return (
    <div className="lab">
      <LevelHeader
        path="/lab"
        right={
          <div className="lab-header-meta">
            <div>
              <b>{TOPICS.length}</b>
              <span>Topics</span>
            </div>
            <div>
              <b>{count ?? 0}</b>
              <span>Explored</span>
            </div>
          </div>
        }
      />
      <nav className="lab-seg lab-tabs" aria-label="Lab sections">
        {TABS.map((t) => (
          <NavLink key={t.to} to={t.to} end={t.end} className={({ isActive }) => `lab-seg-btn${isActive ? ' active' : ''}`}>
            {t.label}
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

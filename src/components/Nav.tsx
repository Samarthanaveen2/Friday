import { NavLink } from 'react-router-dom'
import { LEVELS } from '../lib/levels'

export default function Nav() {
  return (
    <nav className="nav">
      <div className="nav-brand">
        <div className="nav-brand-title">Samartha</div>
        <div className="nav-brand-sub">Tower</div>
      </div>
      {LEVELS.map((l) => (
        <NavLink
          key={l.path}
          to={l.path}
          end={l.path === '/'}
          className={({ isActive }) => 'nav-link' + (isActive ? ' active' : '')}
          style={{ ['--accent' as string]: l.accent }}
        >
          <span className="nav-num">{l.number}</span>
          <span className="nav-text">
            <span>{l.name}</span>
            <span className="nav-trait">{l.trait}</span>
          </span>
        </NavLink>
      ))}
    </nav>
  )
}

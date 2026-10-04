import type { ReactNode } from 'react'
import { Link } from 'react-router-dom'
import { LEVELS } from '../../lib/levels'
import type { ReactorData } from './useReactorData'

interface CardModel {
  path: string
  headline: string
  stat: { label: string; value: string }
  progress: number // 0..1
  done: boolean
  cta: string
}

function plural(n: number, one: string, many = one + 's') {
  return `${n} ${n === 1 ? one : many}`
}

const ICONS: Record<string, ReactNode> = {
  // checklist
  '/negotiator': (
    <>
      <path d="M5 7.5l1.6 1.6L9.5 6" />
      <path d="M5 14.5l1.6 1.6 2.9-3.1" />
      <path d="M12.5 8h6.5M12.5 15h6.5" />
    </>
  ),
  // speech bubble
  '/truth': <path d="M5 6.5h14a1.5 1.5 0 0 1 1.5 1.5v7a1.5 1.5 0 0 1-1.5 1.5h-7l-4 3v-3H5A1.5 1.5 0 0 1 3.5 15V8A1.5 1.5 0 0 1 5 6.5z" />,
  // flask
  '/lab': (
    <>
      <path d="M9.5 4h5M10.5 4v5.5L5.6 18a1.4 1.4 0 0 0 1.2 2h10.4a1.4 1.4 0 0 0 1.2-2l-4.9-8.5V4" />
      <path d="M8 14.5h8" />
    </>
  ),
  // flame
  '/forge': <path d="M12 3.5c.5 3-2.5 4.5-2.5 7.5a2.5 2.5 0 0 0 5 0c0-1-.4-1.8-.9-2.5 2.4 1 4.4 3.6 4.4 6.5a6 6 0 0 1-12 0c0-4.6 4.5-7 6-11.5z" />,
}

function buildCards(d: ReactorData): CardModel[] {
  const { negotiator: n, truth: t, lab: l, forge: f } = d

  const negHeadline = !n.deal
    ? 'No plan for today yet'
    : n.status === 'kept'
      ? 'Deal kept'
      : n.status === 'broken'
        ? 'Deal broken — worth a fresh look'
        : n.status === 'partial'
          ? 'Deal partly kept'
          : 'Deal made, in progress'

  return [
    {
      path: '/negotiator',
      headline: negHeadline,
      stat: n.deal ? { label: 'items', value: `${n.itemsDone}/${n.itemsTotal}` } : { label: 'today', value: 'Open' },
      progress: n.score,
      done: n.status === 'kept',
      cta: !n.deal ? 'Plan today' : n.status === 'open' ? 'Continue the deal' : 'View the deal',
    },
    {
      path: '/truth',
      headline: t.today > 0 ? `${plural(t.today, 'truth')} written today` : 'Nothing written yet today',
      stat: { label: 'day streak', value: String(t.streak) },
      progress: t.score,
      done: t.today > 0,
      cta: t.today > 0 ? 'Open Truth' : 'Write one truth',
    },
    {
      path: '/lab',
      headline: l.today > 0 ? `${plural(l.today, 'idea')} explored today` : 'Nothing explored yet today',
      stat: { label: l.total === 1 ? 'entry' : 'entries', value: String(l.total) },
      progress: l.score,
      done: l.today > 0,
      cta: l.today > 0 ? 'Open the Lab' : 'Explore something',
    },
    {
      path: '/forge',
      headline:
        f.habits === 0
          ? 'No habits yet'
          : f.doneToday >= f.habits
            ? 'All habits done today'
            : `${plural(f.habits - f.doneToday, 'habit')} left today`,
      stat: { label: 'done', value: `${f.doneToday}/${f.habits}` },
      progress: f.score,
      done: f.habits > 0 && f.doneToday >= f.habits,
      cta: f.habits === 0 ? 'Add your first habit' : f.doneToday >= f.habits ? 'Open the Forge' : 'Check in',
    },
  ]
}

export default function LevelCards({ data }: { data: ReactorData }) {
  const cards = buildCards(data)
  return (
    <section className="home-cards" aria-label="Levels">
      {cards.map((c) => {
        const level = LEVELS.find((lv) => lv.path === c.path)!
        return (
          <Link
            key={c.path}
            to={c.path}
            className={'panel home-card' + (c.done ? ' done' : '')}
            style={{ ['--accent' as string]: level.accent }}
            aria-label={`${level.name}: ${c.headline}. ${c.cta}`}
          >
            <span className="home-card-icon" aria-hidden>
              <svg viewBox="0 0 24 24" width="18" height="18">
                {ICONS[c.path]}
              </svg>
            </span>
            <div className="home-card-body">
              <h3 className="home-card-name">{level.name}</h3>
              <p className="home-card-status">
                {c.done && (
                  <svg viewBox="0 0 16 16" width="13" height="13" className="home-card-check" aria-hidden>
                    <path d="M3.5 8.5l3 3 6-7" />
                  </svg>
                )}
                {c.headline}
              </p>
            </div>
            <div className="home-card-stat">
              <span className="home-card-stat-value">{c.stat.value}</span>
              <span className="home-card-stat-label">{c.stat.label}</span>
            </div>
            <svg viewBox="0 0 8 14" width="8" height="14" className="home-card-chevron" aria-hidden>
              <path d="M1.5 1.5L6.5 7l-5 5.5" />
            </svg>
          </Link>
        )
      })}
    </section>
  )
}

import { Link } from 'react-router-dom'
import { LEVELS } from '../../lib/levels'
import type { ReactorData } from './useReactorData'

interface CardModel {
  path: string
  headline: string
  stats: { label: string; value: string }[]
  progress: number // 0..1
  done: boolean
  cta: string
}

function plural(n: number, one: string, many = one + 's') {
  return `${n} ${n === 1 ? one : many}`
}

function buildCards(d: ReactorData): CardModel[] {
  const { negotiator: n, truth: t, lab: l, forge: f } = d

  const negHeadline = !n.deal
    ? 'No deal struck yet'
    : n.status === 'kept'
      ? 'Deal kept'
      : n.status === 'broken'
        ? 'Deal broken. Own it, renegotiate.'
        : n.status === 'partial'
          ? 'Deal partly kept'
          : 'Deal sealed, in progress'

  return [
    {
      path: '/negotiator',
      headline: negHeadline,
      stats: n.deal
        ? [
            { label: 'Items', value: `${n.itemsDone}/${n.itemsTotal}` },
            { label: 'Rules', value: String(n.deal.rules?.length ?? 0) },
          ]
        : [{ label: 'Today', value: 'open' }],
      progress: n.score,
      done: n.status === 'kept',
      cta: !n.deal ? "Negotiate today's deal →" : n.status === 'open' ? 'Work the deal →' : 'See the deal →',
    },
    {
      path: '/truth',
      headline: t.today > 0 ? `${plural(t.today, 'truth')} spoken today` : 'Nothing said out loud yet today',
      stats: [
        { label: 'This week', value: String(t.thisWeek) },
        { label: 'Streak', value: plural(t.streak, 'day') },
      ],
      progress: t.score,
      done: t.today > 0,
      cta: t.today > 0 ? 'Open the chamber →' : 'Speak one truth →',
    },
    {
      path: '/lab',
      headline: l.today > 0 ? `${plural(l.today, 'rabbit hole')} explored today` : 'The lab is quiet today',
      stats: [
        { label: 'Entries', value: String(l.total) },
        { label: 'Topics', value: String(l.topics) },
      ],
      progress: l.score,
      done: l.today > 0,
      cta: l.today > 0 ? 'Back to the lab →' : 'Fall down a rabbit hole →',
    },
    {
      path: '/forge',
      headline:
        f.habits === 0
          ? 'No habits forged yet'
          : f.doneToday >= f.habits
            ? 'Every vote cast today'
            : `${f.habits - f.doneToday} ${f.habits - f.doneToday === 1 ? 'vote' : 'votes'} left today`,
      stats: [{ label: 'Done today', value: `${f.doneToday}/${f.habits}` }],
      progress: f.score,
      done: f.habits > 0 && f.doneToday >= f.habits,
      cta: f.habits === 0 ? 'Forge your first habit →' : f.doneToday >= f.habits ? 'Visit the forge →' : "Cast today's votes →",
    },
  ]
}

export default function LevelCards({ data }: { data: ReactorData }) {
  const cards = buildCards(data)
  return (
    <section className="rx-cards" aria-label="Levels">
      {cards.map((c) => {
        const level = LEVELS.find((lv) => lv.path === c.path)!
        return (
          <Link
            key={c.path}
            to={c.path}
            className={'rx-card' + (c.done ? ' rx-card-done' : '')}
            style={{ ['--accent' as string]: level.accent }}
          >
            <div className="rx-card-top">
              <span className="rx-card-num">L{level.number}</span>
              <span className="rx-card-trait">{level.trait}</span>
              <span className={'rx-card-dot' + (c.done ? ' on' : c.progress > 0 ? ' half' : '')} aria-hidden />
            </div>
            <h3 className="rx-card-name">{level.name}</h3>
            <p className="rx-card-headline">{c.headline}</p>
            <div className="rx-card-stats">
              {c.stats.map((s) => (
                <div key={s.label} className="rx-card-stat">
                  <span className="rx-card-stat-value">{s.value}</span>
                  <span className="rx-card-stat-label">{s.label}</span>
                </div>
              ))}
            </div>
            <div className="rx-bar" aria-hidden>
              <div className="rx-bar-fill" style={{ width: `${Math.round(c.progress * 100)}%` }} />
            </div>
            <span className={'rx-card-cta' + (c.done ? '' : ' rx-card-cta-strong')}>{c.cta}</span>
          </Link>
        )
      })}
    </section>
  )
}

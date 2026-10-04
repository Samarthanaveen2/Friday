import type { LabEntry } from '../../db/types'
import { CATEGORY_COLORS, findTopic, type Category } from './topics'

/** LabEntry plus the extra (non-indexed) fields the Lab stores. */
export interface LabEntryX extends LabEntry {
  prompt?: string // the collision prompt shown when it was saved
  categories?: string[] // category of each topic, parallel to `topics`
}

export function colorFor(name: string): string {
  const t = findTopic(name)
  return t ? CATEGORY_COLORS[t.category as Category] : 'var(--purple)'
}

export function searchUrls(query: string) {
  const q = encodeURIComponent(query)
  return [
    { label: 'Google', href: `https://www.google.com/search?q=${q}` },
    { label: 'Wikipedia', href: `https://en.wikipedia.org/wiki/Special:Search?search=${q}` },
    { label: 'YouTube', href: `https://www.youtube.com/results?search_query=${q}` },
  ]
}

export function SearchLinks({ query, compact }: { query: string; compact?: boolean }) {
  return (
    <div className="lab-search">
      {searchUrls(query).map((s) => (
        <a
          key={s.label}
          className={`lab-search-link${compact ? ' compact' : ''}`}
          href={s.href}
          target="_blank"
          rel="noopener noreferrer"
        >
          {s.label}
        </a>
      ))}
    </div>
  )
}

export function TopicPill({ name, onClick }: { name: string; onClick?: () => void }) {
  const style = { ['--c' as string]: colorFor(name) }
  if (onClick)
    return (
      <button type="button" className="lab-pill" style={style} onClick={onClick}>
        {name}
      </button>
    )
  return (
    <span className="lab-pill" style={style}>
      {name}
    </span>
  )
}

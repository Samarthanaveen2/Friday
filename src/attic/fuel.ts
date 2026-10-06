// Openness fuel: how well each facet has been fed, from logged explorations and done dares.
import type { Dare } from '../db/types'
import { addDays, dayKey } from '../lib/date'
import { CATEGORY_FACET, FACETS, isFacet, type Facet } from './facets'
import type { LabEntryX } from './shared'
import { findTopic, type Category } from './topics'

export const WINDOW_DAYS = 30
const DAY = 86_400_000

/** Fuel points: 1 per topic explored, +1 if you wrote about it, 3 per dare done. */
export const POINTS = { topic: 1, wrote: 1, dare: 3 }

export type FacetScores = Record<Facet, number>

const zero = (): FacetScores => Object.fromEntries(FACETS.map((f) => [f, 0])) as FacetScores

export function categoryOf(entry: LabEntryX, i: number): Category | undefined {
  return (entry.categories?.[i] as Category | undefined) ?? findTopic(entry.topics[i])?.category
}

export function facetScores(entries: LabEntryX[], dares: Dare[], since = 0): FacetScores {
  const s = zero()
  for (const e of entries) {
    if (e.createdAt < since) continue
    const wrote = !!(e.notes || e.connection)
    e.topics.forEach((_, i) => {
      const c = categoryOf(e, i)
      const f = c && CATEGORY_FACET[c]
      if (f) s[f] += POINTS.topic + (wrote ? POINTS.wrote : 0)
    })
  }
  for (const d of dares) {
    if (d.status === 'done' && (d.doneAt ?? 0) >= since && isFacet(d.facet)) s[d.facet] += POINTS.dare
  }
  return s
}

export function recentScores(entries: LabEntryX[], dares: Dare[], now = Date.now()): FacetScores {
  return facetScores(entries, dares, now - WINDOW_DAYS * DAY)
}

/** The facet with the least fuel (ties go to the facet listed first). */
export function weakestFacet(scores: FacetScores): Facet {
  return FACETS.reduce((min, f) => (scores[f] < scores[min] ? f : min), FACETS[0])
}

/** Days (as day keys) on which you explored something or finished a dare. */
export function activeDays(entries: LabEntryX[], dares: Dare[]): Set<string> {
  const days = new Set<string>()
  for (const e of entries) days.add(dayKey(new Date(e.createdAt)))
  for (const d of dares) if (d.status === 'done' && d.doneAt) days.add(dayKey(new Date(d.doneAt)))
  return days
}

/** Consecutive active days ending today, or yesterday if today has no activity yet. */
export function streak(days: Set<string>, today = dayKey()): number {
  let key = days.has(today) ? today : addDays(today, -1)
  let n = 0
  while (days.has(key)) {
    n++
    key = addDays(key, -1)
  }
  return n
}

/** How many times each category has been explored (all time). */
export function categoryCounts(entries: LabEntryX[]): Map<Category, number> {
  const m = new Map<Category, number>()
  for (const e of entries)
    e.topics.forEach((_, i) => {
      const c = categoryOf(e, i)
      if (c) m.set(c, (m.get(c) ?? 0) + 1)
    })
  return m
}

import { useEffect } from 'react'
import { useLiveQuery } from 'dexie-react-hooks'
import { db, setSetting } from '../../db/db'
import type { IfThenRule } from '../../db/types'

/**
 * Standing if-then rules. Unlike wants and needs, they don't belong to one day's deal:
 * they stay in force every day until removed, so a lesson learned once keeps applying.
 */
export const RULES_KEY = 'negotiator.rules'

export function saveRules(rules: IfThenRule[]) {
  return setSetting(
    RULES_KEY,
    rules.map(({ id, when, then }) => ({ id, when, then })),
  )
}

/** Rules people wrote into past deals, before rules were standing. Oldest first, deduped. */
async function rulesFromPastDeals(): Promise<IfThenRule[]> {
  const deals = await db.deals.orderBy('createdAt').toArray()
  const seen = new Set<string>()
  const out: IfThenRule[] = []
  for (const d of deals) {
    for (const r of d.rules ?? []) {
      const k = `${r.when.trim().toLowerCase()}|${r.then.trim().toLowerCase()}`
      if (seen.has(k)) continue
      seen.add(k)
      out.push({ id: r.id, when: r.when, then: r.then })
    }
  }
  return out
}

/** The standing rules, or undefined while loading. Seeds itself from past deals the first time. */
export function useStandingRules(): IfThenRule[] | undefined {
  const row = useLiveQuery(() => db.settings.get(RULES_KEY).then((r) => r ?? null), [])
  useEffect(() => {
    if (row === null) rulesFromPastDeals().then(saveRules)
  }, [row])
  return row ? (row.value as IfThenRule[]) : undefined
}

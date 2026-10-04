// Shared data model for every level of the Tower.
// Dates are stored as 'YYYY-MM-DD' day keys (see lib/date.ts); timestamps as epoch ms.

export interface DealItem {
  id: string
  text: string
  minutes?: number
  done?: boolean
}

export interface IfThenRule {
  id: string
  when: string // "If it's 9pm..."
  then: string // "...then the phone goes in the other room"
  kept?: boolean
}

export type DealStatus = 'open' | 'kept' | 'partial' | 'broken'

/** Level 1 — a negotiated day between Present You and Future You. */
export interface Deal {
  id?: number
  date: string // day key, one deal per day
  wants: DealItem[] // what Present You asked for
  needs: DealItem[] // what Future You demanded
  rules: IfThenRule[]
  status: DealStatus
  review?: string
  createdAt: number
  reviewedAt?: number
}

export type TruthKind = 'lie' | 'avoided' | 'self'
export type TruthStatus = 'confessed' | 'addressed' | 'pattern'

/** Level 2 — a truth spoken out loud (to yourself first). */
export interface Truth {
  id?: number
  createdAt: number
  text: string
  kind: TruthKind
  who?: string
  topic?: string
  status: TruthStatus
  tags: string[]
}

/** Level 3 — a rabbit hole / collision explored in the Lab. */
export interface LabEntry {
  id?: number
  createdAt: number
  topics: string[] // the topics drawn (1 = single, 2-3 = collision)
  connection?: string // how they connect
  notes?: string // what was learned
  links: string[]
  starred?: boolean
}

/** Level 4 — a keystone habit with an identity attached. */
export interface Habit {
  id?: number
  name: string
  identity: string // "I am someone who..."
  createdAt: number
  archived?: boolean
}

export interface HabitLog {
  id?: number
  habitId: number
  date: string // day key
  done: boolean
}

export interface WeeklyReview {
  id?: number
  weekStart: string // day key of Monday
  broke: string
  why: string
  fix: string
  createdAt: number
}

/** Reactor — letters across time. */
export interface Letter {
  id?: number
  createdAt: number
  unlockAt: number
  body: string
  to: 'future' | 'present' // written to future self, or "from" future self to present
  opened?: boolean
}

export interface Setting {
  key: string
  value: unknown
}

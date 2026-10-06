// Data model for the Attic.
// Timestamps are epoch ms.

/** A rabbit hole / collision explored in the Attic. */
export interface LabEntry {
  id?: number
  createdAt: number
  topics: string[] // the topics drawn (1 = single, 2-3 = collision)
  connection?: string // how they connect
  notes?: string // what was learned
  links: string[]
  starred?: boolean
}

export type DareStatus = 'todo' | 'done'

/** A real-world openness dare: something new to try, see, feel or question. */
export interface Dare {
  id?: number
  createdAt: number
  text: string
  facet: string // a Facet id (see attic/facets.ts)
  status: DareStatus
  doneAt?: number
  reflection?: string
}

export interface Setting {
  key: string
  value: unknown
}

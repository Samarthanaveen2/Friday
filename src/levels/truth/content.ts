import type { Truth, TruthKind, TruthStatus } from '../../db/types'

/** Truth with the extra (non-indexed) fields this level stores. */
export interface TruthEntry extends Truth {
  addressedAt?: number
  patternAt?: number
  /** The courage prompt shown when it was written. */
  prompt?: string
}

export const KIND_LABEL: Record<TruthKind, string> = {
  lie: 'Lie',
  avoided: 'Avoided truth',
  self: 'Self-deception',
}

export const KIND_HINT: Record<TruthKind, string> = {
  lie: 'Something I said that wasn’t true',
  avoided: 'Something true I didn’t say',
  self: 'A story I told myself',
}

export const STATUS_LABEL: Record<TruthStatus, string> = {
  confessed: 'Confessed',
  addressed: 'Addressed',
  pattern: 'Pattern',
}

export const STATUS_HINT: Record<TruthStatus, string> = {
  confessed: 'Written down. That counts.',
  addressed: 'Told the person, or fixed it',
  pattern: 'Keeps coming back — worth watching',
}

export const PROMPTS: string[] = [
  'What did I pretend today?',
  'What am I avoiding saying?',
  'Who did I mislead, including myself?',
  'What would I say if I knew there were no consequences?',
  'Where did I say “I’m fine” and not mean it?',
  'What did I agree to that I didn’t want?',
  'What am I telling myself I’ll do “later”?',
  'What did I exaggerate to look better?',
  'What did I downplay so no one would worry?',
  'Whose opinion did I nod along with?',
  'What excuse did I use today?',
  'What do I already know, but don’t want to know?',
  'What compliment did I give that I didn’t mean?',
  'What feeling did I hide behind a joke?',
  'What promise to myself did I quietly drop?',
  'What did I blame on circumstances that was really a choice?',
  'What question did I dodge?',
  'What did I let someone believe because correcting it felt awkward?',
  'What am I hoping no one will ask me about?',
  'What would Future Me want me to admit right now?',
  'What did I say “yes” to when I meant “no”?',
  'What am I calling “rest” that is really avoidance?',
  'What do I keep saying I don’t care about?',
  'Which apology have I been putting off?',
  'What did I hide from the people closest to me this week?',
  'What story about myself am I outgrowing?',
  'If my friend did what I did today, what would I tell them?',
  'What’s the smallest true sentence I’ve been afraid to write?',
]

export const ACKS: string[] = [
  'Said. It’s lighter out here than in there.',
  'That took something. It’s on the page now.',
  'The truth is out of your head and into the room.',
  'One true sentence. That’s how it starts.',
  'Noted, not judged.',
  'You looked straight at it. That’s the hard part.',
  'Written down means you don’t have to carry it alone.',
  'Honesty with yourself first. The rest can follow.',
  'Future You just got a clearer map.',
  'No verdict here. Just the truth, kept safe.',
  'You named it. Named things are smaller.',
  'Quiet courage still counts.',
]

export const ADDRESSED_ACKS: string[] = [
  'You said it out loud. That’s real courage.',
  'Closed the loop. Well done.',
  'From the page into the world.',
]

export function pick<T>(arr: T[], not?: T): T {
  if (arr.length < 2) return arr[0]
  let x = arr[Math.floor(Math.random() * arr.length)]
  while (x === not) x = arr[Math.floor(Math.random() * arr.length)]
  return x
}

export function timeAgo(ts: number, now = Date.now()): string {
  const s = Math.max(0, Math.round((now - ts) / 1000))
  if (s < 60) return 'just now'
  const m = Math.round(s / 60)
  if (m < 60) return `${m}m ago`
  const h = Math.round(m / 60)
  if (h < 24) return `${h}h ago`
  const d = Math.round(h / 24)
  if (d < 30) return `${d}d ago`
  return new Date(ts).toLocaleDateString(undefined, { month: 'short', day: 'numeric', year: 'numeric' })
}

export const DAY_MS = 24 * 60 * 60 * 1000

export function parseTags(s: string): string[] {
  return Array.from(
    new Set(
      s
        .split(/[,#]/)
        .map((t) => t.trim().toLowerCase())
        .filter(Boolean),
    ),
  )
}

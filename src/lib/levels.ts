// Registry of the Tower's levels — used by navigation and the Reactor.
export interface LevelInfo {
  path: string
  number: string
  name: string
  trait: string
  tagline: string
  accent: string
}

export const LEVELS: LevelInfo[] = [
  { path: '/', number: '00', name: 'Home', trait: 'Today', tagline: 'Where today meets the future', accent: 'var(--blue)' },
  { path: '/negotiator', number: '01', name: 'Negotiator', trait: 'Planning', tagline: 'Strike a deal with Future You', accent: 'var(--indigo)' },
  { path: '/truth', number: '02', name: 'Truth Chamber', trait: 'Honesty', tagline: 'Say the thing', accent: 'var(--red)' },
  { path: '/lab', number: '03', name: 'The Lab', trait: 'Openness', tagline: 'Let the mind run wild', accent: 'var(--purple)' },
  { path: '/forge', number: '04', name: 'The Forge', trait: 'Conscientiousness', tagline: 'Become someone fixed, not broken', accent: 'var(--orange)' },
  { path: '/vault', number: '∞', name: 'Vault', trait: 'System', tagline: 'Backups, lock and settings', accent: 'var(--faint)' },
]

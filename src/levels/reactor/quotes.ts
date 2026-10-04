// Lines from Carl Jung and Jordan Peterson.
// One is picked deterministically per day.
export type Quote = { text: string; by: string }

export const FUTURE_LINES: Quote[] = [
  { text: "Compare yourself to who you were yesterday, not to who someone else is today.", by: 'Jordan Peterson' },
  { text: "Who looks outside, dreams; who looks inside, awakes.", by: 'Carl Jung' },
  { text: "Treat yourself like someone you are responsible for helping.", by: 'Jordan Peterson' },
  { text: "One does not become enlightened by imagining figures of light, but by making the darkness conscious.", by: 'Carl Jung' },
  { text: "To stand up straight with your shoulders back is to accept the terrible responsibility of life, with eyes wide open.", by: 'Jordan Peterson' },
  { text: "No tree, it is said, can grow to heaven unless its roots reach down to hell.", by: 'Carl Jung' },
  { text: "Pursue what is meaningful, not what is expedient.", by: 'Jordan Peterson' },
  { text: "Everything that irritates us about others can lead us to an understanding of ourselves.", by: 'Carl Jung' },
  { text: "Tell the truth, or, at least, don't lie.", by: 'Jordan Peterson' },
  { text: "Knowing your own darkness is the best method for dealing with the darknesses of other people.", by: 'Carl Jung' },
  { text: "Set your house in perfect order before you criticize the world.", by: 'Jordan Peterson' },
  { text: "There is no coming to consciousness without pain.", by: 'Carl Jung' },
  { text: "Assume that the person you are listening to might know something you don't.", by: 'Jordan Peterson' },
  { text: "Man needs difficulties; they are necessary for health.", by: 'Carl Jung' },
  { text: "Be precise in your speech.", by: 'Jordan Peterson' },
  { text: "In all chaos there is a cosmos, in all disorder a secret order.", by: 'Carl Jung' },
  { text: "Make friends with people who want the best for you.", by: 'Jordan Peterson' },
  { text: "The shoe that fits one person pinches another; there is no recipe for living that suits all cases.", by: 'Carl Jung' },
  { text: "Aim up. Pay attention. Fix what you can fix. Don't be arrogant in your knowledge.", by: 'Jordan Peterson' },
  { text: "The meeting of two personalities is like the contact of two chemical substances: if there is any reaction, both are transformed.", by: 'Carl Jung' },
  { text: "Imagine who you could be, and then aim single-mindedly at that.", by: 'Jordan Peterson' },
  { text: "Loneliness does not come from having no people about one, but from being unable to communicate the things that seem important to oneself.", by: 'Carl Jung' },
  { text: "Work as hard as you possibly can on at least one thing and see what happens.", by: 'Jordan Peterson' },
  { text: "The pendulum of the mind oscillates between sense and nonsense, not between right and wrong.", by: 'Carl Jung' },
  { text: "Notice that opportunity lurks where responsibility has been abdicated.", by: 'Jordan Peterson' },
  { text: "Where love rules, there is no will to power; and where power predominates, there love is lacking.", by: 'Carl Jung' },
  { text: "Do not hide unwanted things in the fog.", by: 'Jordan Peterson' },
  { text: "The healthy man does not torture others. Generally it is the tortured who turn into torturers.", by: 'Carl Jung' },
  { text: "Do not do what you hate.", by: 'Jordan Peterson' },
  { text: "Be grateful in spite of your suffering.", by: 'Jordan Peterson' },
  { text: "Try to make one room in your home as beautiful as possible.", by: 'Jordan Peterson' },
  { text: "Do not allow yourself to become resentful, deceitful, or arrogant.", by: 'Jordan Peterson' },
]

/** Deterministic index for a day key (stable all day, changes each day). */
export function lineIndexForDay(key: string): number {
  let h = 2166136261
  for (let i = 0; i < key.length; i++) {
    h ^= key.charCodeAt(i)
    h = Math.imul(h, 16777619)
  }
  return Math.abs(h) % FUTURE_LINES.length
}

// Thinking prompts. {A}, {B}, {C} are replaced with drawn topic names.
import { CATEGORY_FACET, SINGLE_PROMPTS } from './facets'
import type { Topic } from './topics'

export const PAIR_PROMPTS: string[] = [
  'What would {A} look like if it were designed by {B}?',
  'Explain {A} using only the vocabulary of {B}.',
  'What problem do {A} and {B} secretly share?',
  'If {A} and {B} had a child, what would it be called and what would it do?',
  'Write the opening line of a novel set at the intersection of {A} and {B}.',
  'What would a museum exhibit called "{A} × {B}" contain?',
  'Which one would win an argument, {A} or {B}, and what would they argue about?',
  'What can {B} teach someone who has spent their life studying {A}?',
  'Imagine {A} is a metaphor for {B}. Where does the metaphor break?',
  'Design a festival that celebrates both {A} and {B}.',
  'What would a 10-year-old notice about {A} and {B} that an expert would miss?',
  'If {A} were a country, what would its relationship with {B} be?',
  'Find a hidden pattern, rhythm or structure that {A} and {B} have in common.',
  'What is the most beautiful thing about {A}, and how could {B} make it more beautiful?',
  'Describe {A} as a recipe, with {B} as the secret ingredient.',
  'What question would a scholar of {B} ask about {A} that no one has asked yet?',
  'Turn {A} and {B} into a board game. What are the rules and how do you win?',
  'What if {A} were invented 1,000 years earlier, by people obsessed with {B}?',
  'Write a haiku that contains both {A} and {B} without naming either.',
  'Where in your own life do {A} and {B} already collide?',
  'What would a protest about {A} sound like if it were organised by fans of {B}?',
  'Use {B} to make {A} feel strange again, as if you were seeing it for the first time.',
  'Which assumption about {A} would {B} quietly demolish?',
  'Sketch (in words) a building inspired by {A} and furnished according to {B}.',
  'What is the one-sentence thesis of an essay titled "{A} Is Just {B} in Disguise"?',
  'If {A} and {B} were characters in a myth, who is the trickster and who is the hero?',
  'What tool, ritual or app would exist in a world where {A} and {B} were the same thing?',
  'Name three things that are true of both {A} and {B}. Then name the weirdest one.',
  'What would an expert in {A} find beautiful about {B}?',
  'What belief would you have to drop to see {A} and {B} as the same thing?',
  'Plan a one-day trip that lets you experience both {A} and {B} first-hand.',
  'Write a two-line dialogue between {A} and {B} arguing about what matters most.',
  'What feeling sits underneath both {A} and {B}?',
  'If {A} were a dish, how would {B} change the recipe?',
  'What would {A} look like in the year 2300, after {B} has changed everything?',
  'What’s a question about {A} that only someone obsessed with {B} would ask?',
  'Make up a word for the space where {A} meets {B}, and define it.',
  'What would you do differently this week if you took both {A} and {B} seriously?',
]

export const TRIPLE_PROMPTS: string[] = [
  '{A} is the setting, {B} is the conflict, {C} is the resolution. Tell the story.',
  'Design a university course that teaches {A}, {B} and {C} as one subject. What is it called?',
  'Which of {A}, {B} and {C} is the odd one out, and what argument makes it belong after all?',
  'Build a theory of everything using only {A}, {B} and {C}.',
  '{A} asks a question, {B} gives the wrong answer, {C} gives the right one. What happened?',
  'Plan a dinner party for {A}, {B} and {C}. Who sits next to whom, and what do they talk about?',
  'Draw a triangle: put {A}, {B} and {C} at the corners. What lives in the middle?',
  'If {A} and {B} are the problem, how is {C} the solution?',
  'Write a three-line poem: one line each for {A}, {B} and {C}.',
  'You can only keep one of {A}, {B} and {C} in the world. Which, and what do you lose?',
  'Open a café themed on {A}, {B} and {C}. What is on the menu?',
]

export function pickPrompt(names: string[], seed = Math.random()): string {
  const pool = names.length >= 3 ? [...TRIPLE_PROMPTS, ...PAIR_PROMPTS] : PAIR_PROMPTS
  const tpl = pool[Math.floor(seed * pool.length) % pool.length]
  return fillPrompt(tpl, names)
}

export function fillPrompt(tpl: string, names: string[]): string {
  return tpl
    .replaceAll('{A}', names[0] ?? '?')
    .replaceAll('{B}', names[1] ?? '?')
    .replaceAll('{C}', names[2] ?? names[0] ?? '?')
}

/** A prompt for a single topic, tuned to the facet its category feeds. */
export function pickSinglePrompt(topic: Topic, seed = Math.random()): string {
  const pool = SINGLE_PROMPTS[CATEGORY_FACET[topic.category]]
  return fillPrompt(pool[Math.floor(seed * pool.length) % pool.length], [topic.name])
}

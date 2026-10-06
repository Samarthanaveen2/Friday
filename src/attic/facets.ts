// The six facets of Openness to Experience (after the NEO-PI-R: Ideas, Fantasy,
// Aesthetics, Feelings, Actions, Values), renamed for everyday use. Every category
// feeds one facet, and every dare trains one, so the Attic can show which parts of
// an open mind are well fed and which are starving.
import type { Category } from './topics'

export const FACETS = ['ideas', 'imagination', 'beauty', 'feelings', 'adventure', 'values'] as const
export type Facet = (typeof FACETS)[number]

export interface FacetInfo {
  id: Facet
  name: string
  blurb: string
  color: string
}

export const FACET_INFO: Record<Facet, FacetInfo> = {
  ideas: { id: 'ideas', name: 'Ideas', blurb: 'Intellectual hunger: puzzles, theories, how things work.', color: '#007aff' },
  imagination: { id: 'imagination', name: 'Imagination', blurb: 'Daydreams, stories, other worlds and what-ifs.', color: '#af52de' },
  beauty: { id: 'beauty', name: 'Beauty', blurb: 'Being moved by art, craft, form and design.', color: '#ff2d55' },
  feelings: { id: 'feelings', name: 'Feelings', blurb: 'Noticing and naming your inner weather.', color: '#ff9500' },
  adventure: { id: 'adventure', name: 'Adventure', blurb: 'New places, foods, routines and experiences.', color: '#34c759' },
  values: { id: 'values', name: 'Values', blurb: 'Re-examining beliefs, customs and the way things are done.', color: '#5e5ce6' },
}

export const CATEGORY_FACET: Record<Category, Facet> = {
  Science: 'ideas',
  Mathematics: 'ideas',
  Philosophy: 'ideas',
  Technology: 'ideas',
  'Economics & Game Theory': 'ideas',
  Language: 'ideas',
  'Cosmos & Space': 'ideas',
  'The Body & Medicine': 'ideas',
  Literature: 'imagination',
  'Religion & Myth': 'imagination',
  'Futures & Speculation': 'imagination',
  'Strange but True': 'imagination',
  'Games & Play': 'imagination',
  Art: 'beauty',
  'Architecture & Design': 'beauty',
  'Cinema & Film': 'beauty',
  'Crafts & Making': 'beauty',
  Psychology: 'feelings',
  Music: 'feelings',
  'Emotions & Inner Life': 'feelings',
  'Nature & Biology': 'adventure',
  'Food & Cuisine': 'adventure',
  'Places & Geography': 'adventure',
  History: 'values',
  'Culture & Anthropology': 'values',
  'Ethics & Dilemmas': 'values',
}

export function categoriesOf(facet: Facet): Category[] {
  return (Object.keys(CATEGORY_FACET) as Category[]).filter((c) => CATEGORY_FACET[c] === facet)
}

export function isFacet(x: unknown): x is Facet {
  return typeof x === 'string' && (FACETS as readonly string[]).includes(x)
}

// Real-world dares: small, doable-today ways to stretch each facet.
export const DARES: Record<Facet, string[]> = {
  ideas: [
    'Open Wikipedia’s random article page and read whatever comes up, top to bottom.',
    'Pick something you use every day and find out exactly how it works.',
    'Learn one equation and explain it out loud to someone (or your phone camera).',
    'Ask “why?” five times about something you believe, and write each answer down.',
    'Watch a lecture on a subject you know nothing about, at normal speed, no phone.',
    'Find a scientific paper on a question you care about and read the abstract and conclusion.',
    'Teach yourself a card trick, a knot or a simple proof, then teach it to someone.',
    'Write down three things you’re certain of. Find the best argument against one of them.',
    'Go down a rabbit hole for 30 minutes, following only links that surprise you.',
    'Learn 10 words in a language whose script you can’t read yet.',
    'Look at the night sky and find one constellation you couldn’t name before.',
    'Read the opening chapter of a classic in a field you’ve never studied.',
    'Pick a historical invention and work out what problem it actually solved.',
    'Write a one-page explanation of something hard, then cut it to one paragraph.',
    'Visit a museum room you would normally walk past.',
  ],
  imagination: [
    'Write a 100-word story where one law of physics changes every Tuesday.',
    'Spend 10 minutes daydreaming on purpose. No phone, no music, just drift.',
    'Write down a dream as soon as you wake up, before it fades.',
    'Invent a creature and describe its habitat, diet and one strange habit.',
    'Imagine your life if you’d been born 300 years ago. Write a day of it.',
    'Read a myth from a culture you know nothing about.',
    'Tell someone a made-up story and let them choose what happens next.',
    'Design a holiday that doesn’t exist yet: its rituals, food and songs.',
    'Write a letter from yourself 20 years from now.',
    'Draw a map of a place that exists only in your head.',
    'Watch clouds for five minutes and name everything you see in them.',
    'Rewrite the ending of a film or book you didn’t like.',
    'Play a game you haven’t played since you were a child.',
    'Imagine a world without one ordinary invention (say, the clock). What changes?',
    'Write the first page of a novel with a title picked at random from a bookshelf.',
  ],
  beauty: [
    'Sit in front of one artwork for 10 full minutes. Write what changed as you looked.',
    'Listen to a whole album, start to finish, with your eyes closed.',
    'Photograph 10 beautiful things within 100 metres of where you are.',
    'Go and watch the sunrise or sunset without photographing it.',
    'Make something with your hands, however badly: a sketch, a fold, a loaf, a stitch.',
    'Rearrange one corner of your room until it feels right.',
    'Listen to a genre of music you think you don’t like, for a full 20 minutes.',
    'Read a poem aloud, slowly, twice.',
    'Watch a film from a country whose cinema you have never seen.',
    'Find the most beautiful building you can walk to and study its details.',
    'Cook a meal and plate it as carefully as a restaurant would.',
    'Sketch a plant, leaf or flower from life for 15 minutes.',
    'Hum or sing along to a song you love, out loud, all the way through.',
    'Visit a gallery or exhibition you’d never normally choose.',
    'Notice every colour in one view, and try to name each precisely.',
  ],
  feelings: [
    'Three times today, name exactly what you feel using a word more precise than “good” or “bad”.',
    'Write for 15 minutes about something that still stings, without editing.',
    'Tell someone specifically why you’re grateful for them.',
    'Listen to a piece of music that makes you sad, and let it.',
    'When you next feel irritated, pause and ask what the feeling is protecting.',
    'Watch a film that made you cry once, and notice when it starts to get to you.',
    'Do a 10-minute body scan: where in your body do you feel today?',
    'Ask a friend how they really are, and then just listen.',
    'Write a letter to your younger self about something they were scared of.',
    'Spend an hour fully alone, without screens. Notice what comes up.',
    'Notice one moment of awe today, however small, and write it down.',
    'Name an emotion you avoid feeling. Write about the last time you felt it.',
    'Say “I don’t know how I feel” out loud, then keep talking until you do.',
    'Read a memoir chapter by someone whose life is very different from yours.',
    'End the day by writing the best and the hardest moment.',
  ],
  adventure: [
    'Take a route home you have never taken.',
    'Eat a cuisine you’ve never tried, and order the dish you can’t pronounce.',
    'Go somewhere in your town you’ve never been: a park, a market, a street.',
    'Try a class, sport or hobby for one session, just to see.',
    'Talk to a stranger and ask them about their work.',
    'Change one part of your daily routine for a whole day.',
    'Cook a recipe from a country you couldn’t point to on a map.',
    'Go for a walk with no destination, turning whichever way looks interesting.',
    'Wake up early and be outside at first light.',
    'Buy a fruit or vegetable you’ve never eaten and figure out how to eat it.',
    'Spend an afternoon somewhere without your phone.',
    'Swim, hike or climb somewhere new.',
    'Say yes to the next invitation you would normally turn down.',
    'Go to an event alone: a talk, a gig, a gathering.',
    'Sleep or sit outside for an hour and just watch what happens.',
  ],
  values: [
    'Steelman a view you disagree with, in writing, until its holder would nod.',
    'Read an opinion column from the publication you trust least, charitably.',
    'Attend a religious service or ceremony from a tradition not your own.',
    'Ask someone older than you what they believed at your age that they no longer do.',
    'List three rules you follow that nobody ever explained. Keep or drop each.',
    'Find a custom from another culture that seems strange, and learn why it exists.',
    'Change your mind about one small thing today, and say so out loud.',
    'Read the other side’s best book on a debate you care about.',
    'Write down what you would do if no one would ever know. Is it what you do now?',
    'Talk with someone from a very different background about what a good life is.',
    'Pick one thing everyone around you agrees on and ask: what if it’s wrong?',
    'Learn the history of a place name or street name near you.',
    'Spend a day noticing every time you judge someone, without acting on it.',
    'Read a primary source from a historical event, not a summary of it.',
    'Write your own definition of success, without using money or status.',
  ],
}

/** Thinking prompts for a single topic, one set per facet so they stretch that muscle. */
export const SINGLE_PROMPTS: Record<Facet, string[]> = {
  ideas: [
    'What is the single most surprising fact about {A}? Why does it surprise you?',
    'Explain {A} to a curious 10-year-old in three sentences.',
    'What question about {A} is still unanswered?',
    'What would you have to believe for {A} to make perfect sense?',
  ],
  imagination: [
    'Write the opening line of a story that begins inside {A}.',
    'If {A} were a person, what would they want, and what would they fear?',
    'Imagine {A} a thousand years from now. What has it become?',
    'What would a world built entirely around {A} look like?',
  ],
  beauty: [
    'What is beautiful about {A}, even if nobody else sees it?',
    'If {A} were a colour, a texture and a sound, which would it be?',
    'How would you make {A} into an object you could hold?',
    'Describe {A} as a painting. What is in the foreground?',
  ],
  feelings: [
    'What feeling does {A} stir in you, and why that one?',
    'Who in your life would light up talking about {A}?',
    'When have you felt like {A}?',
    'What would someone who loves {A} want you to notice?',
  ],
  adventure: [
    'How could you experience {A} with your own senses this month?',
    'Where in the world would you go to see {A} up close?',
    'What is one small thing you could try today because of {A}?',
    'Who has actually done or been to {A}, and what did they say about it?',
  ],
  values: [
    'What does {A} reveal about what people value?',
    'How would someone from another century judge {A}?',
    'What belief of yours does {A} quietly challenge?',
    'Who benefits from {A}, and who pays for it?',
  ],
}

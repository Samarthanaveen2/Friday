export interface Preset {
  text: string
  minutes?: number
}

export const WANT_PRESETS: Preset[] = [
  { text: 'Scrolling', minutes: 30 },
  { text: 'Gaming', minutes: 60 },
  { text: 'YouTube / shows', minutes: 45 },
  { text: 'Lie-in', minutes: 30 },
  { text: 'Nap', minutes: 20 },
  { text: 'Long lunch with friends', minutes: 60 },
  { text: 'Rabbit-hole browsing', minutes: 30 },
  { text: 'Doing nothing, guilt-free', minutes: 30 },
]

export const NEED_PRESETS: Preset[] = [
  { text: 'Deep work block', minutes: 90 },
  { text: 'Workout', minutes: 45 },
  { text: 'Walk outside', minutes: 30 },
  { text: 'Practice a skill', minutes: 30 },
  { text: 'Read a book', minutes: 20 },
  { text: 'Life admin', minutes: 20 },
  { text: 'Meditate', minutes: 10 },
  { text: 'Cook a real meal', minutes: 40 },
]

export const RULE_PRESETS: { when: string; then: string }[] = [
  { when: 'I pick up my phone without a reason', then: 'put it face-down and take one breath first' },
  { when: "it's 10pm", then: 'the phone goes to charge in another room' },
  { when: 'I feel the urge to quit a hard task', then: 'do 5 more minutes before deciding' },
  { when: 'I finish lunch', then: 'start the next need immediately, no "quick check"' },
  { when: 'I notice I am spiralling or anxious', then: 'walk for 5 minutes and name what I feel' },
  { when: 'I open a game or feed', then: 'set a timer for the minutes I paid for' },
  { when: 'I break a part of the deal', then: 'renegotiate honestly instead of giving up on the day' },
]

export const NEGOTIATION_LINES = [
  'Future You is sitting across the table. They remember everything you choose today.',
  'Present You is not the enemy. Just a hungry negotiator. Feed them fairly.',
  'Every minute you want, Future You pays for. Make it a fair trade.',
  'The person living your life in a year is real. Today you decide what they inherit.',
]

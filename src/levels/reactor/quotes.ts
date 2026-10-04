// Short lines about sacrifice, future self and delayed gratification.
// One is picked deterministically per day.
export const FUTURE_LINES: string[] = [
  'Future You is not a stranger. They are you, with your choices already made.',
  'Every "later" you say is a bill addressed to someone you will become.',
  'The version of you in a year is built from what you repeat this week.',
  'Discipline is remembering what you want most, not what you want now.',
  'You are always paying. The only question is now, or later with interest.',
  'Comfort today is borrowed from tomorrow. Borrow carefully.',
  'Someone you love will live inside your future. Be kind to them.',
  'Small, boring, repeated. That is what the future is made of.',
  'You will not rise to your goals. You will fall to your defaults.',
  'The sacrifice feels big because the future feels far. It is not far.',
  'One year from now you will wish you had started today.',
  'What would the person you want to be do in the next ten minutes?',
  'Waiting is not losing. Waiting is how you buy something bigger.',
  'The present is loud. The future speaks quietly. Listen anyway.',
  'Treat Future You like a friend you have promised something to.',
  'Every kept promise to yourself is a vote for who you are becoming.',
  'You cannot skip the middle. You can only shorten it by starting.',
  'Motivation is a visitor. Systems are residents.',
  'The hard thing you do today is a gift you open later.',
  'Short-term you is persuasive. Let long-term you have the last word.',
  'Your future self is watching this exact moment through memory.',
  'Not today is how never begins.',
  'The pain of discipline weighs ounces. The pain of regret weighs tons.',
  'You do not need a perfect day. You need a day that counts.',
  'Plant the tree whose shade you will sit in.',
  'Today is the oldest you have ever been and the youngest you will ever be again.',
  'Interest compounds on habits exactly like it does on money.',
  'Ask: will Future You thank me for this, or apologise for me?',
  'Delay the reward and you get to keep the person who earned it.',
  'A future you can picture is a future you will protect.',
  'Tiny deposits. Every day. That is the whole trick.',
  'Do it for the person who has to wake up as you tomorrow.',
  'You are the ancestor of everyone you will ever be.',
  'Hard choices, easier life. Easy choices, harder life.',
  'The moment you are trying to escape is the one that builds you.',
  'What you do daily matters more than what you do once in a while.',
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

// A typed confirmation (EXPERIENCE.md, Delete dialog): whether what the
// player typed or pasted is the word, in any case, surrounding spaces
// ignored. The server applies the same rule (AccountsController).
export function matchesWord(typed: string, word: string): boolean {
  return word.length > 0 && typed.trim().toUpperCase() === word.toUpperCase()
}

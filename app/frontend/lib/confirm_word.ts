// Whether what the player typed or pasted is the word, in any case, surrounding spaces ignored; the server applies the same rule.
export function matchesWord(typed: string, word: string): boolean {
  return word.length > 0 && typed.trim().toUpperCase() === word.toUpperCase()
}

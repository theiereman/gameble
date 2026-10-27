export function matchesWord(typed: string, word: string): boolean {
  return word.length > 0 && typed.trim().toUpperCase() === word.toUpperCase()
}

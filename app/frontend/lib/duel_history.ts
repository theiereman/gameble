export function showRound(scope: ParentNode, number: string): void {
  const rounds = Array.from(scope.querySelectorAll<HTMLElement>("[data-history-round]"))
  if (!rounds.some((round) => round.dataset.historyRound === number)) return

  rounds.forEach((round) => (round.hidden = round.dataset.historyRound !== number))
}

export function showLatestRound(scope: ParentNode): void {
  const rounds = Array.from(scope.querySelectorAll<HTMLElement>("[data-history-round]"))
  const latest = rounds.at(-1)?.dataset.historyRound
  if (latest) showRound(scope, latest)
}

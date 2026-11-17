import type { DuelState } from "./duel"

type Choices = Pick<DuelState, "card" | "stat" | "direction">

function radios(scope: ParentNode, name: string): HTMLInputElement[] {
  return Array.from(scope.querySelectorAll<HTMLInputElement>(`input[name="${name}"]`))
}

type SetKey = "duelCard" | "duelStat"

function showSets(group: HTMLElement | null, key: SetKey, active: string | null, chosen: string | null): void {
  if (!group) return
  group.hidden = active === null
  group.querySelectorAll<HTMLElement>("[data-duel-card], [data-duel-stat]").forEach((set) => {
    const open = set.dataset[key] === active
    set.hidden = !open
    set.querySelectorAll<HTMLInputElement>("input").forEach((radio) => {
      radio.disabled = !open
      radio.checked = open && radio.value === chosen
    })
  })
}

export function renderChoices(form: HTMLElement, choices: Choices): void {
  radios(form, "card").forEach((radio) => (radio.checked = radio.value === choices.card))
  showSets(form.querySelector<HTMLElement>("[data-duel-group=stat]"), "duelCard", choices.card, choices.stat)
  showSets(form.querySelector<HTMLElement>("[data-duel-group=direction]"), "duelStat", choices.stat, choices.direction)
}

export function submitButton(form: HTMLElement): HTMLElement | null {
  return form.querySelector<HTMLElement>("button[type=submit]")
}

export function handCards(board: HTMLElement): HTMLElement[] {
  return Array.from(board.querySelectorAll<HTMLElement>("#duel-hand [data-card]"))
}

export function focusTarget(board: HTMLElement): HTMLElement | null {
  const reveal = board.querySelector<HTMLElement>("#duel-reveal:not([hidden]) #duel-reveal-heading")
  if (reveal) return reveal
  const result = board.querySelector<HTMLElement>("#duel-result-heading")
  if (result) return result
  const cards = radios(board, "card")
  return cards.find((radio) => radio.checked) ?? cards[0] ?? board.querySelector<HTMLElement>("#duel-round-heading")
}

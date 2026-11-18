import type { DuelState } from "./duel"

type Choices = Pick<DuelState, "card" | "stat" | "direction">

function radios(scope: ParentNode, name: string): HTMLInputElement[] {
  return Array.from(scope.querySelectorAll<HTMLInputElement>(`input[name="${name}"]`))
}

function cardRadios(form: HTMLElement): HTMLInputElement[] {
  return radios(form.ownerDocument, "card").filter((radio) => radio.form === form)
}

function setValue(form: HTMLElement, name: string, value: string | null): void {
  const field = form.querySelector<HTMLInputElement>(`input[type=hidden][name="${name}"]`)
  if (field) field.value = value ?? ""
}

export function renderChoices(form: HTMLElement, choices: Choices): void {
  const page = form.ownerDocument
  cardRadios(form).forEach((radio) => (radio.checked = radio.value === choices.card))
  page.querySelectorAll<HTMLElement>("[data-duel-card]").forEach((set) => {
    set.hidden = set.dataset.duelCard !== choices.card
  })
  page.querySelectorAll<HTMLElement>("[data-duel-pick]").forEach((button) => {
    const [stat, direction] = (button.dataset.duelPick ?? "").split(":")
    button.setAttribute("aria-pressed", String(stat === choices.stat && direction === choices.direction))
  })
  page.querySelectorAll<HTMLElement>("[data-duel-stat]").forEach((row) => {
    row.toggleAttribute("data-chosen", row.dataset.duelStat === choices.stat)
  })
  page.querySelectorAll<HTMLElement>(".duel-table__chosen .stat-bars__row").forEach((row) => {
    const picked = choices.direction !== null && row.dataset.stat === choices.stat
    row.toggleAttribute("data-picked", picked)
    if (picked && choices.direction) row.dataset.direction = choices.direction
    else delete row.dataset.direction
  })
  setValue(form, "stat", choices.stat)
  setValue(form, "direction", choices.direction)
}

export function submitButton(form: HTMLElement): HTMLElement | null {
  return form.querySelector<HTMLElement>("button[type=submit]")
}

export function handCards(board: HTMLElement): HTMLElement[] {
  return Array.from(board.querySelectorAll<HTMLElement>("#duel-my-deck [data-card]"))
}

export function focusTarget(board: HTMLElement): HTMLElement | null {
  const reveal = board.querySelector<HTMLElement>("#duel-reveal:not([hidden]) #duel-reveal-heading")
  if (reveal) return reveal
  const result = board.querySelector<HTMLElement>("#duel-result-heading")
  if (result) return result
  const cards = radios(board, "card")
  return cards.find((radio) => radio.checked) ?? cards[0] ?? board.querySelector<HTMLElement>("#duel-round-heading")
}

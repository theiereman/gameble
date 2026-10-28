import { Controller } from "@hotwired/stimulus"
import type { Reserve } from "../lib/booster"
import { writeText } from "../lib/dom_writes"

export type ReservesView = Readonly<{
  selected: Reserve
  tabs: Readonly<Record<Reserve, Readonly<{ label: string; empty: boolean }>>>
}>

export type ReserveIntent = { reserve: Reserve }

export default class BoosterReservesController extends Controller<HTMLElement> {
  static targets = ["tab", "label", "reason"]

  declare readonly tabTargets: HTMLButtonElement[]

  render({ selected, tabs }: ReservesView): void {
    for (const tab of this.tabTargets) {
      const reserve = tab.dataset.reserve as Reserve
      const { label, empty } = tabs[reserve]
      tab.disabled = empty
      tab.setAttribute("aria-selected", String(reserve === selected))
      writeText(tab.querySelector<HTMLElement>("[data-booster-reserves-target~='label']")!, label)
      const reason = tab.querySelector<HTMLElement>("[data-booster-reserves-target~='reason']")
      if (reason) reason.hidden = !empty
    }
  }

  select({ currentTarget }: Event): void {
    const reserve = (currentTarget as HTMLElement).dataset.reserve as Reserve
    this.dispatch("select", { detail: { reserve } })
  }
}

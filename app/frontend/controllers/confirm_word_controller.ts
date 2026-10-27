import { Controller } from "@hotwired/stimulus"
import { matchesWord } from "../lib/confirm_word"

export default class extends Controller<HTMLFormElement> {
  static targets = ["field", "submit"]
  static values = { word: String }

  declare readonly fieldTarget: HTMLInputElement
  declare readonly submitTarget: HTMLButtonElement
  declare readonly wordValue: string

  connect(): void {
    this.check()
  }

  check(): void {
    this.submitTarget.disabled = !matchesWord(this.fieldTarget.value, this.wordValue)
  }
}

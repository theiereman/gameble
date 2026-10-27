import { Controller } from "@hotwired/stimulus"
import { matchesWord } from "../lib/confirm_word"

// A form confirmed by typing a word: its submit button is enabled only while the field holds the word, in any case.
// Without JavaScript the button stays enabled and the server checks the word alone.
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

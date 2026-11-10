import { Controller } from "@hotwired/stimulus"
import { writeText } from "../lib/dom_writes"

export default class AnnonceStatusController extends Controller<HTMLElement> {
  say(text: string): void {
    writeText(this.element, text)
  }
}

import { Controller } from "@hotwired/stimulus"
import { ClerkSignIn, type ClerkLike, type MessageKey, type Messages, type Outcome } from "../lib/clerk_sign_in"

type Mode = "start" | "callback"

export default class extends Controller<HTMLElement> {
  static targets = ["provider", "email", "code", "emailStep", "codeStep", "error", "status", "form"]
  static values = {
    publishableKey: String,
    mode: { type: String, default: "start" },
    callbackUrl: String,
    completeUrl: String,
    messages: Object,
  }

  declare readonly providerTargets: HTMLButtonElement[]
  declare readonly emailTarget: HTMLInputElement
  declare readonly codeTarget: HTMLInputElement
  declare readonly emailStepTarget: HTMLElement
  declare readonly codeStepTarget: HTMLElement
  declare readonly errorTarget: HTMLElement
  declare readonly statusTarget: HTMLElement
  declare readonly formTarget: HTMLFormElement
  declare readonly hasErrorTarget: boolean
  declare readonly hasStatusTarget: boolean
  declare readonly hasEmailStepTarget: boolean
  declare readonly hasCodeStepTarget: boolean
  declare readonly publishableKeyValue: string
  declare readonly modeValue: Mode
  declare readonly callbackUrlValue: string
  declare readonly completeUrlValue: string
  declare readonly messagesValue: Messages

  private signIn: ClerkSignIn | null = null
  private ready: Promise<boolean> | null = null
  private busy = false

  connect(): void {
    this.showStep("email")
    this.setBusy(true)
    this.ready = this.load()
    void this.ready.then((loaded) => {
      if (loaded) this.setBusy(false)
    })
  }

  disconnect(): void {
    this.signIn = null
    this.ready = null
  }

  async start(event: Event & { params: { strategy?: string } }): Promise<void> {
    event.preventDefault()
    const strategy = event.params.strategy
    if (strategy !== "oauth_discord" && strategy !== "oauth_google") return
    await this.run((signIn) => signIn.startOAuth(strategy))
  }

  async sendCode(event: Event): Promise<void> {
    event.preventDefault()
    await this.run((signIn) => signIn.sendCode(this.emailTarget.value))
  }

  async verifyCode(event: Event): Promise<void> {
    event.preventDefault()
    await this.run((signIn) => signIn.verifyCode(this.codeTarget.value))
  }

  back(event: Event): void {
    event.preventDefault()
    if (!this.signIn || this.busy) return
    this.signIn.back()
    this.codeTarget.value = ""
    this.showStep("email")
    this.report("")
    this.emailTarget.focus()
  }

  private async load(): Promise<boolean> {
    try {
      const { Clerk } = await import("@clerk/clerk-js/no-rhc")
      const clerk = new Clerk(this.publishableKeyValue)
      await clerk.load({ telemetry: false })
      this.signIn = new ClerkSignIn(clerk as unknown as ClerkLike, {
        callbackUrl: this.callbackUrlValue,
        completeUrl: this.completeUrlValue,
      })
    } catch {
      this.reportKey("network")
      return false
    }
    return this.begin(this.signIn)
  }

  private async begin(signIn: ClerkSignIn): Promise<boolean> {
    if (this.modeValue === "callback") {
      this.setStatus("signingIn")
      const outcome = await signIn.completeRedirect()
      this.apply(outcome)
      return outcome.kind === "failed"
    }
    const outcome = await signIn.prepareFreshStart()
    if (outcome?.kind === "failed") {
      this.apply(outcome)
      return false
    }
    return true
  }

  private async run(action: (signIn: ClerkSignIn) => Promise<Outcome>): Promise<void> {
    if (this.busy || !this.ready) return
    if (!(await this.ready) || !this.signIn) return
    this.report("")
    this.setBusy(true)
    const outcome = await action(this.signIn)
    this.apply(outcome)
    if (outcome.kind === "failed" || outcome.kind === "codeSent") this.setBusy(false)
  }

  private apply(outcome: Outcome): void {
    switch (outcome.kind) {
      case "signedIn":
        this.setStatus("signingIn")
        this.formTarget.requestSubmit()
        break
      case "codeSent":
        this.showStep("code")
        this.setStatus(outcome.message)
        this.codeTarget.focus()
        break
      case "failed":
        this.reportKey(outcome.message)
        break
      default:
        break
    }
  }

  private showStep(step: "email" | "code"): void {
    if (this.hasEmailStepTarget) this.emailStepTarget.hidden = step !== "email"
    if (this.hasCodeStepTarget) this.codeStepTarget.hidden = step !== "code"
  }

  private setBusy(busy: boolean): void {
    this.busy = busy
    this.element.setAttribute("aria-busy", String(busy))
    for (const control of this.element.querySelectorAll<HTMLButtonElement>("button")) {
      control.disabled = busy
    }
  }

  private setStatus(key: MessageKey): void {
    if (!this.hasStatusTarget) return
    this.errorTargetText("")
    this.statusTarget.textContent = this.messagesValue[key] ?? ""
  }

  private reportKey(key: MessageKey): void {
    this.report(this.messagesValue[key] ?? this.messagesValue.generic ?? "")
  }

  private report(text: string): void {
    this.errorTargetText(text)
    if (text !== "" && this.hasStatusTarget) this.statusTarget.textContent = ""
  }

  private errorTargetText(text: string): void {
    if (this.hasErrorTarget) this.errorTarget.textContent = text
  }
}

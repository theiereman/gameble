export type MessageKey =
  | "generic"
  | "network"
  | "codeIncorrect"
  | "codeExpired"
  | "tooManyRequests"
  | "captcha"
  | "invalidEmail"
  | "codeSent"
  | "loading"
  | "signingIn"

export type Messages = Record<MessageKey, string>

type Strategy = "oauth_discord" | "oauth_google"
type Flow = "signIn" | "signUp"
type Step = "email" | "code"

interface Attempt {
  status: string | null
  createdSessionId: string | null
}

interface SignInLike {
  create(params: { identifier: string; strategy: "email_code" }): Promise<unknown>
  attemptFirstFactor(params: { strategy: "email_code"; code: string }): Promise<Attempt>
  authenticateWithRedirect(params: {
    strategy: Strategy
    redirectUrl: string
    redirectUrlComplete: string
  }): Promise<unknown>
}

interface SignUpLike {
  create(params: { emailAddress: string }): Promise<unknown>
  prepareEmailAddressVerification(params: { strategy: "email_code" }): Promise<unknown>
  attemptEmailAddressVerification(params: { code: string }): Promise<Attempt>
}

export interface ClerkLike {
  session?: unknown
  client?: { signIn: SignInLike; signUp: SignUpLike } | undefined
  signOut(afterSignOut?: () => Promise<unknown>): Promise<unknown>
  setActive(params: { session: string }): Promise<unknown>
  handleRedirectCallback(
    params: {
      signInUrl: string
      signUpUrl: string
      signInFallbackRedirectUrl: string
      signUpFallbackRedirectUrl: string
    },
    navigate: () => Promise<unknown>,
  ): Promise<unknown>
}

export interface SignInConfig {
  callbackUrl: string
  completeUrl: string
}

export type Outcome =
  | { kind: "signedIn" }
  | { kind: "redirecting" }
  | { kind: "codeSent"; message: MessageKey }
  | { kind: "emailStep" }
  | { kind: "failed"; message: MessageKey }

const ERROR_KEYS: Record<string, MessageKey> = {
  form_code_incorrect: "codeIncorrect",
  form_code_expired: "codeExpired",
  verification_failed: "codeExpired",
  verification_expired: "codeExpired",
  too_many_requests: "tooManyRequests",
  rate_limit_exceeded: "tooManyRequests",
  network_error: "network",
  form_param_format_invalid: "invalidEmail",
  form_identifier_invalid: "invalidEmail",
  form_param_nil: "invalidEmail",
}

const IDENTIFIER_UNKNOWN = "form_identifier_not_found"

function errorCodes(error: unknown): string[] {
  if (typeof error !== "object" || error === null) return []
  const { errors, code } = error as { errors?: unknown; code?: unknown }
  const codes: string[] = []
  if (Array.isArray(errors)) {
    for (const entry of errors) {
      const entryCode = (entry as { code?: unknown } | null)?.code
      if (typeof entryCode === "string") codes.push(entryCode)
    }
  }
  if (typeof code === "string") codes.push(code)
  return codes
}

export function messageKeyForError(error: unknown): MessageKey {
  if (error instanceof TypeError) return "network"
  for (const code of errorCodes(error)) {
    if (code.startsWith("captcha")) return "captcha"
    const key = ERROR_KEYS[code]
    if (key) return key
  }
  return "generic"
}

function isUnknownIdentifier(error: unknown): boolean {
  return errorCodes(error).includes(IDENTIFIER_UNKNOWN)
}

export class ClerkSignIn {
  private flow: Flow = "signIn"
  private step: Step = "email"

  constructor(
    private readonly clerk: ClerkLike,
    private readonly config: SignInConfig,
  ) {}

  get currentStep(): Step {
    return this.step
  }

  async prepareFreshStart(): Promise<Outcome | null> {
    if (!this.clerk.session) return null
    return this.attempt(async () => {
      // Clerk's signOut navigates to its after-sign-out URL unless it is given a callback.
      await this.clerk.signOut(async () => undefined)
      return null
    })
  }

  async startOAuth(strategy: Strategy): Promise<Outcome> {
    return this.attempt(async () => {
      await this.requireClient().signIn.authenticateWithRedirect({
        strategy,
        redirectUrl: this.config.callbackUrl,
        redirectUrlComplete: this.config.completeUrl,
      })
      return { kind: "redirecting" }
    })
  }

  async completeRedirect(): Promise<Outcome> {
    return this.attempt(async () => {
      const { callbackUrl, completeUrl } = this.config
      await this.clerk.handleRedirectCallback(
        {
          signInUrl: callbackUrl,
          signUpUrl: callbackUrl,
          signInFallbackRedirectUrl: completeUrl,
          signUpFallbackRedirectUrl: completeUrl,
        },
        async () => undefined,
      )
      if (this.clerk.session) return { kind: "signedIn" }
      console.error("Clerk returned without a session")
      return { kind: "failed", message: "generic" }
    })
  }

  async sendCode(email: string): Promise<Outcome> {
    const identifier = email.trim()
    if (identifier === "") return { kind: "failed", message: "invalidEmail" }
    return this.attempt(async () => {
      const { signIn, signUp } = this.requireClient()
      try {
        await signIn.create({ identifier, strategy: "email_code" })
        this.flow = "signIn"
      } catch (error) {
        if (!isUnknownIdentifier(error)) throw error
        await signUp.create({ emailAddress: identifier })
        await signUp.prepareEmailAddressVerification({ strategy: "email_code" })
        this.flow = "signUp"
      }
      this.step = "code"
      return { kind: "codeSent", message: "codeSent" }
    })
  }

  async verifyCode(code: string): Promise<Outcome> {
    const trimmed = code.trim()
    if (trimmed === "") return { kind: "failed", message: "codeIncorrect" }
    return this.attempt(async () => {
      const { signIn, signUp } = this.requireClient()
      const result =
        this.flow === "signIn"
          ? await signIn.attemptFirstFactor({ strategy: "email_code", code: trimmed })
          : await signUp.attemptEmailAddressVerification({ code: trimmed })
      if (result.status !== "complete" || !result.createdSessionId) {
        return { kind: "failed", message: "generic" }
      }
      await this.clerk.setActive({ session: result.createdSessionId })
      return { kind: "signedIn" }
    })
  }

  back(): Outcome {
    this.step = "email"
    this.flow = "signIn"
    return { kind: "emailStep" }
  }

  private requireClient(): NonNullable<ClerkLike["client"]> {
    if (!this.clerk.client) throw new Error("clerk client unavailable")
    return this.clerk.client
  }

  private async attempt(run: () => Promise<Outcome | null>): Promise<Outcome> {
    try {
      return (await run()) ?? { kind: "emailStep" }
    } catch (error) {
      console.error("Clerk sign-in failed", error)
      return { kind: "failed", message: messageKeyForError(error) }
    }
  }
}

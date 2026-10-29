import { describe, expect, it, vi } from "vitest"
import { ClerkSignIn, messageKeyForError, type ClerkLike } from "./clerk_sign_in"

const config = {
  callbackUrl: "https://example.test/en/sign-in/callback",
  completeUrl: "https://example.test/en/sign-in/callback",
}

function clerkError(code: string) {
  return { errors: [{ code, message: "raw clerk text" }] }
}

function buildFake(overrides: { session?: unknown } = {}) {
  const signIn = {
    create: vi.fn(async () => ({})),
    attemptFirstFactor: vi.fn(async () => ({ status: "complete", createdSessionId: "sess_1" })),
    authenticateWithRedirect: vi.fn(async () => undefined),
  }
  const signUp = {
    create: vi.fn(async () => ({})),
    prepareEmailAddressVerification: vi.fn(async () => ({})),
    attemptEmailAddressVerification: vi.fn(async () => ({ status: "complete", createdSessionId: "sess_2" })),
  }
  const clerk = {
    session: overrides.session ?? null,
    client: { signIn, signUp },
    signOut: vi.fn(async () => undefined),
    setActive: vi.fn(async () => undefined),
    handleRedirectCallback: vi.fn(async () => undefined),
  }
  return { clerk, signIn, signUp, driver: new ClerkSignIn(clerk as unknown as ClerkLike, config) }
}

describe("prepareFreshStart", () => {
  it("signs out an existing session", async () => {
    const { clerk, driver } = buildFake({ session: { id: "sess_old" } })
    await driver.prepareFreshStart()
    expect(clerk.signOut).toHaveBeenCalledOnce()
  })

  it("signs out without letting Clerk navigate away from the screen", async () => {
    const { clerk, driver } = buildFake({ session: { id: "sess_old" } })
    await driver.prepareFreshStart()
    expect(clerk.signOut).toHaveBeenCalledWith(expect.any(Function))
  })

  it("leaves a signed-out visitor alone", async () => {
    const { clerk, driver } = buildFake()
    expect(await driver.prepareFreshStart()).toBeNull()
    expect(clerk.signOut).not.toHaveBeenCalled()
  })

  it("reports a failed sign out", async () => {
    const { clerk, driver } = buildFake({ session: {} })
    clerk.signOut.mockRejectedValue(new TypeError("Failed to fetch"))
    expect(await driver.prepareFreshStart()).toEqual({ kind: "failed", message: "network" })
  })
})

describe("startOAuth", () => {
  it("redirects through the callback", async () => {
    const { signIn, driver } = buildFake()
    expect(await driver.startOAuth("oauth_discord")).toEqual({ kind: "redirecting" })
    expect(signIn.authenticateWithRedirect).toHaveBeenCalledWith({
      strategy: "oauth_discord",
      redirectUrl: config.callbackUrl,
      redirectUrlComplete: config.completeUrl,
    })
  })

  it("maps a failure to a message key", async () => {
    const { signIn, driver } = buildFake()
    signIn.authenticateWithRedirect.mockRejectedValue(clerkError("captcha_invalid"))
    expect(await driver.startOAuth("oauth_google")).toEqual({ kind: "failed", message: "captcha" })
  })
})

describe("completeRedirect", () => {
  it("signs in when Clerk holds a session afterwards", async () => {
    const { clerk, driver } = buildFake()
    clerk.handleRedirectCallback.mockImplementation(async () => {
      clerk.session = { id: "sess_1" }
    })
    expect(await driver.completeRedirect()).toEqual({ kind: "signedIn" })
  })

  it("fails when no session results", async () => {
    const { driver } = buildFake()
    expect(await driver.completeRedirect()).toEqual({ kind: "failed", message: "generic" })
  })

  it("fails when the callback throws", async () => {
    const { clerk, driver } = buildFake()
    clerk.handleRedirectCallback.mockRejectedValue(clerkError("too_many_requests"))
    expect(await driver.completeRedirect()).toEqual({ kind: "failed", message: "tooManyRequests" })
  })
})

describe("email code", () => {
  it("sends a sign-in code to a known identifier", async () => {
    const { signIn, signUp, driver } = buildFake()
    expect(await driver.sendCode(" a@b.test ")).toEqual({ kind: "codeSent", message: "codeSent" })
    expect(signIn.create).toHaveBeenCalledWith({ identifier: "a@b.test", strategy: "email_code" })
    expect(signUp.create).not.toHaveBeenCalled()
    expect(driver.currentStep).toBe("code")
  })

  it("falls back to sign-up for an unknown identifier", async () => {
    const { signIn, signUp, driver } = buildFake()
    signIn.create.mockRejectedValue(clerkError("form_identifier_not_found"))
    expect(await driver.sendCode("new@b.test")).toEqual({ kind: "codeSent", message: "codeSent" })
    expect(signUp.create).toHaveBeenCalledWith({ emailAddress: "new@b.test" })
    expect(signUp.prepareEmailAddressVerification).toHaveBeenCalledWith({ strategy: "email_code" })
  })

  it("does not fall back on other sign-in errors", async () => {
    const { signIn, signUp, driver } = buildFake()
    signIn.create.mockRejectedValue(clerkError("too_many_requests"))
    expect(await driver.sendCode("a@b.test")).toEqual({ kind: "failed", message: "tooManyRequests" })
    expect(signUp.create).not.toHaveBeenCalled()
    expect(driver.currentStep).toBe("email")
  })

  it("reports a failing sign-up fallback", async () => {
    const { signIn, signUp, driver } = buildFake()
    signIn.create.mockRejectedValue(clerkError("form_identifier_not_found"))
    signUp.create.mockRejectedValue(clerkError("form_param_format_invalid"))
    expect(await driver.sendCode("bad")).toEqual({ kind: "failed", message: "invalidEmail" })
  })

  it("refuses an empty email without calling Clerk", async () => {
    const { signIn, driver } = buildFake()
    expect(await driver.sendCode("  ")).toEqual({ kind: "failed", message: "invalidEmail" })
    expect(signIn.create).not.toHaveBeenCalled()
  })

  it("verifies a sign-in code and activates the session", async () => {
    const { clerk, signIn, driver } = buildFake()
    await driver.sendCode("a@b.test")
    expect(await driver.verifyCode(" 123456 ")).toEqual({ kind: "signedIn" })
    expect(signIn.attemptFirstFactor).toHaveBeenCalledWith({ strategy: "email_code", code: "123456" })
    expect(clerk.setActive).toHaveBeenCalledWith({ session: "sess_1" })
  })

  it("verifies a sign-up code after the fallback", async () => {
    const { clerk, signIn, signUp, driver } = buildFake()
    signIn.create.mockRejectedValue(clerkError("form_identifier_not_found"))
    await driver.sendCode("new@b.test")
    expect(await driver.verifyCode("123456")).toEqual({ kind: "signedIn" })
    expect(signUp.attemptEmailAddressVerification).toHaveBeenCalledWith({ code: "123456" })
    expect(clerk.setActive).toHaveBeenCalledWith({ session: "sess_2" })
  })

  it("maps wrong and expired codes", async () => {
    const { signIn, driver } = buildFake()
    await driver.sendCode("a@b.test")
    signIn.attemptFirstFactor.mockRejectedValueOnce(clerkError("form_code_incorrect"))
    expect(await driver.verifyCode("000000")).toEqual({ kind: "failed", message: "codeIncorrect" })
    signIn.attemptFirstFactor.mockRejectedValueOnce(clerkError("form_code_expired"))
    expect(await driver.verifyCode("000000")).toEqual({ kind: "failed", message: "codeExpired" })
  })

  it("does not activate a session when verification is incomplete", async () => {
    const { clerk, signIn, driver } = buildFake()
    await driver.sendCode("a@b.test")
    signIn.attemptFirstFactor.mockResolvedValue({ status: "needs_second_factor", createdSessionId: "" })
    expect(await driver.verifyCode("123456")).toEqual({ kind: "failed", message: "generic" })
    expect(clerk.setActive).not.toHaveBeenCalled()
  })

  it("goes back to the email step", async () => {
    const { driver } = buildFake()
    await driver.sendCode("a@b.test")
    expect(driver.back()).toEqual({ kind: "emailStep" })
    expect(driver.currentStep).toBe("email")
  })
})

describe("messageKeyForError", () => {
  it("maps known codes and never leaks raw text", () => {
    expect(messageKeyForError(clerkError("form_code_incorrect"))).toBe("codeIncorrect")
    expect(messageKeyForError(clerkError("form_code_expired"))).toBe("codeExpired")
    expect(messageKeyForError(clerkError("too_many_requests"))).toBe("tooManyRequests")
    expect(messageKeyForError(clerkError("captcha_failed"))).toBe("captcha")
    expect(messageKeyForError({ code: "network_error" })).toBe("network")
    expect(messageKeyForError(new TypeError("Failed to fetch"))).toBe("network")
  })

  it("falls back to the generic key", () => {
    expect(messageKeyForError(clerkError("something_new"))).toBe("generic")
    expect(messageKeyForError(new Error("boom"))).toBe("generic")
    expect(messageKeyForError(null)).toBe("generic")
  })
})

# The only way into Steam's sign-in (DESIGN.md, Steam sign-in): Valve's
# official "Sign in through Steam" image, unmodified (180 × 35), as the
# button of a one-button POST form to /auth/steam. `origin` is where the
# player comes back to; the form is a full-page load (Steam is another
# site). The button keeps a hit area of at least 44px around the image.
# `autofocus: true` makes it the first control focused in a dialog (the
# sign-in panel; EXPERIENCE.md, Modal: never the close button).
class SteamSignInComponent < ViewComponent::Base
  IMAGE = "images/steam/sits_01.png".freeze

  def initialize(origin:, autofocus: false)
    @origin = origin
    @autofocus = autofocus
  end
end

# Steam's sign-in under Valve's official "Sign in through Steam" image
# (DESIGN.md, Steam sign-in), unmodified (180 × 35), as the
# button of a one-button POST form to /auth/steam. `origin` is where the
# player comes back to; the form is a full-page load (Steam is another
# site). The button keeps a hit area of at least 44px around the image.
class SteamSignInComponent < ViewComponent::Base
  IMAGE = "images/steam/sits_01.png".freeze

  def initialize(origin:)
    @origin = origin
  end
end

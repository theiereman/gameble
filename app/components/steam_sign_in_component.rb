class SteamSignInComponent < ViewComponent::Base
  IMAGE = "images/steam/sits_01.png".freeze

  def initialize(origin:)
    @origin = origin
  end
end

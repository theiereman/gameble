# Signing in through OmniAuth's Steam mock: the including test runs with
# OmniAuth's test mode on, and the mock is dropped after each test.
#
#   sign_in(accounts_players(:player))
#   sign_in_new_player("76561197960287930")
#   mock_steam_sign_in(banned.steam_id) # then post "/auth/steam" yourself
#
# A test case signing in from another locale overrides `sign_in_origin`.
module SteamSignIn
  def self.included(test_case)
    test_case.setup { OmniAuth.config.test_mode = true }
    test_case.teardown do
      OmniAuth.config.mock_auth.delete(:steam)
      OmniAuth.config.test_mode = false
    end
  end

  def mock_steam_sign_in(steam_id)
    OmniAuth.config.mock_auth[:steam] = OmniAuth::AuthHash.new(provider: "steam", uid: "https://steamcommunity.com/openid/id/#{steam_id}")
  end

  def sign_in(player, origin: sign_in_origin)
    sign_in_with_steam_id(player.steam_id, origin:)
    assert_equal player.id, session[:player_id]
  end

  def sign_in_new_player(steam_id, origin: sign_in_origin)
    sign_in_with_steam_id(steam_id, origin:)
    assert session[:player_id]
  end

  def sign_in_origin = "/en"

  private

  def sign_in_with_steam_id(steam_id, origin:)
    mock_steam_sign_in(steam_id)
    post "/auth/steam", params: { origin: }
    follow_redirect!
  end
end

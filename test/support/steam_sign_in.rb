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

  SESSION_COOKIE = "_gameble_session".freeze

  # Signs a system test's browser in without its screens: the session the
  # Steam mock opens in a throwaway integration session becomes the browser's
  # cookie, and the browser lands on the home page as after the real sign-in.
  # A test of the sign-in screens themselves clicks through them instead.
  def sign_in_browser(steam_id = nil, locale: :en)
    mock_steam_sign_in(steam_id) if steam_id
    session = ActionDispatch::Integration::Session.new(Rails.application)
    session.post "/auth/steam", params: { origin: "/#{locale}" }
    session.follow_redirect!
    page.driver.browser.execute_cdp("Network.setCookie", name: SESSION_COOKIE, value: CGI.escape(session.cookies[SESSION_COOKIE]),
      url: Capybara.current_session.server.base_url, path: "/")
    visit home_path(locale:)
    assert_signed_in
  end

  private

  def sign_in_with_steam_id(steam_id, origin:)
    mock_steam_sign_in(steam_id)
    post "/auth/steam", params: { origin: }
    follow_redirect!
  end
end

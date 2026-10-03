require "test_helper"
require_relative "../support/steam_api_stubs"

class SessionsControllerTest < ActionDispatch::IntegrationTest
  include SteamApiStubs

  STEAM_ID = "76561197960287930".freeze
  CLAIMED_ID = "https://steamcommunity.com/openid/id/#{STEAM_ID}".freeze

  setup do
    OmniAuth.config.test_mode = true
    mock_steam(CLAIMED_ID)
    stub_steam_api
  end

  teardown do
    OmniAuth.config.mock_auth.delete(:steam)
    OmniAuth.config.test_mode = false
    unstub_steam_api
  end

  def mock_steam(uid)
    OmniAuth.config.mock_auth[:steam] = OmniAuth::AuthHash.new(provider: "steam", uid: uid)
  end

  def sign_in_with_steam(origin: "/en")
    post "/auth/steam", params: { origin: origin }
    assert_redirected_to "http://www.example.com/auth/steam/callback"
    follow_redirect!
  end

  # The players created by these tests, beside the fixture players.
  def new_players
    Accounts::Player.where.not(id: accounts_players.map(&:id))
  end

  def registered_events
    Rails.configuration.event_store.read.of_type(Accounts::PlayerRegistered).to_a
  end

  def signed_in_player_id
    session[:player_id]
  end

  test "a first sign-in creates the player, publishes PlayerRegistered and keeps the player id in the session" do
    sign_in_with_steam

    player = new_players.sole
    assert_equal STEAM_ID, player.steam_id
    assert_predicate player.token, :present?
    assert_equal [ { player_id: player.id } ], registered_events.map(&:data)
    assert_equal player.id, signed_in_player_id
    assert_redirected_to home_path(locale: :en)
    assert_equal "Welcome to the ranks, Brother. The Brotherhood has entered your name in the great ledger.", flash[:notice]

    follow_redirect!
    assert_select ".flash .flash__message--notice", flash[:notice]
  end

  def bank_of(player)
    Game::Pack.where(player_id: player.id)
  end

  def bank_filled_events
    Rails.configuration.event_store.read.of_type(Game::BankFilled).to_a
  end

  test "a first sign-in fills the new player's bank with ten available packs of five cards" do
    Game::DrawPool.reset!

    sign_in_with_steam

    player = new_players.sole
    assert_equal 10, bank_of(player).count
    assert bank_of(player).all? { |pack| pack.card_season_ids.size == 5 && pack.available_at <= Time.current }
    assert_equal [ { player_id: player.id } ], bank_filled_events.map(&:data)
  end

  test "a returning sign-in adds no pack" do
    sign_in_with_steam
    delete session_path(locale: :en)

    sign_in_with_steam

    assert_equal 10, bank_of(new_players.sole).count
    assert_equal 1, bank_filled_events.size
  end

  test "a sign-up with no published season succeeds with an empty bank and no BankFilled" do
    catalog_seasons(:one).update_columns(status: "draft", published_at: nil)

    sign_in_with_steam

    player = new_players.sole
    assert_equal player.id, signed_in_player_id
    assert_equal 0, bank_of(player).count
    assert_empty bank_filled_events
  end

  test "a sign-up whose bank fill raises creates no player, reports the error and fails the sign-in" do
    failing = Object.new
    failing.define_singleton_method(:call) { |**| raise "the bank fill failed" }
    Game::FillBank.define_singleton_method(:new) { failing }
    begin
      assert_error_reported(RuntimeError) { sign_in_with_steam }
    ensure
      Game::FillBank.singleton_class.remove_method(:new)
    end

    assert_equal 0, new_players.count
    assert_empty registered_events
    assert_nil signed_in_player_id
    assert_redirected_to home_path(locale: :en)
    assert_equal I18n.t("errors.accounts.sign_in_failed", locale: :en), flash[:alert]
  end

  test "signing in twice with the same Steam id keeps one player and the same session id" do
    sign_in_with_steam
    first_id = signed_in_player_id

    delete session_path(locale: :en)
    sign_in_with_steam

    assert_equal 1, new_players.count
    assert_equal 1, registered_events.size
    assert_equal first_id, signed_in_player_id
    assert_equal new_players.sole.id, signed_in_player_id
  end

  test "signing in resets the session against fixation and keeps only the player id" do
    post "/auth/steam", params: { origin: "/en" }
    session_id_before = session[:session_id]
    assert session_id_before

    follow_redirect!

    assert_not_equal session_id_before, session[:session_id]
    assert_equal %w[flash player_id session_id], session.to_hash.keys.sort
  end

  test "the welcome follows the locale the sign-in started from" do
    sign_in_with_steam(origin: "/fr")

    assert_redirected_to home_path(locale: :fr)
    assert_equal "Bienvenue dans les rangs, Confrère. La Confrérie a inscrit ton nom au grand registre.", flash[:notice]
  end

  test "a malformed claimed id signs nobody in" do
    mock_steam("https://evil.example/openid/id/123")

    sign_in_with_steam

    assert_equal 0, new_players.count
    assert_empty registered_events
    assert_nil signed_in_player_id
    assert_redirected_to home_path(locale: :en)
    assert_equal I18n.t("errors.steam.invalid_claimed_id", locale: :en), flash[:alert]
  end

  test "an OpenID failure lands on the failure endpoint and signs nobody in" do
    OmniAuth.config.mock_auth[:steam] = :invalid_credentials

    post "/auth/steam", params: { origin: "/fr" }
    follow_redirect!
    assert_redirected_to %r{\A/auth/failure\?message=invalid_credentials}
    follow_redirect!

    assert_equal 0, new_players.count
    assert_nil signed_in_player_id
    assert_redirected_to home_path(locale: :fr)
    assert_equal I18n.t("errors.steam.sign_in_failed", locale: :fr), flash[:alert]
  end

  test "the failure endpoint without an origin answers in the default locale" do
    get auth_failure_path(message: "invalid_credentials")

    assert_redirected_to home_path(locale: I18n.default_locale)
    assert_equal I18n.t("errors.steam.sign_in_failed", locale: I18n.default_locale), flash[:alert]
  end

  test "the failure endpoint ignores a foreign origin" do
    get auth_failure_path(message: "invalid_credentials", origin: "https://evil.example/fr")

    assert_redirected_to home_path(locale: I18n.default_locale)
  end

  test "a callback this browser did not start is refused" do
    get steam_callback_path

    assert_equal 0, new_players.count
    assert_empty registered_events
    assert_nil signed_in_player_id
    assert_redirected_to home_path(locale: I18n.default_locale)
    assert_equal I18n.t("errors.steam.sign_in_failed", locale: I18n.default_locale), flash[:alert]
  end

  test "the sign-in marker is consumed by the callback" do
    sign_in_with_steam
    delete session_path(locale: :en)
    mock_steam("https://steamcommunity.com/openid/id/76561197960287931")

    get steam_callback_path

    assert_nil signed_in_player_id
    assert_equal 1, new_players.count
  end

  test "a signed-in player stays signed in after a failure" do
    sign_in_with_steam
    player_id = signed_in_player_id

    get auth_failure_path(message: "invalid_credentials")

    assert_equal player_id, signed_in_player_id
    assert_equal I18n.t("errors.steam.sign_in_failed", locale: I18n.default_locale), flash[:alert]
  end

  test "a signed-in player stays signed in after a refused callback" do
    sign_in_with_steam
    player_id = signed_in_player_id
    mock_steam("https://evil.example/openid/id/123")

    sign_in_with_steam

    assert_equal player_id, signed_in_player_id
  end

  test "a sign-in returns to the local page it started on" do
    sign_in_with_steam(origin: "/fr/some/page")

    assert_redirected_to "/fr/some/page"
    assert_equal I18n.t("sessions.create.welcome", locale: :fr), flash[:notice]
  end

  test "a refused sign-in returns to the local page it started on" do
    OmniAuth.config.mock_auth[:steam] = :invalid_credentials

    post "/auth/steam", params: { origin: "/fr/some/page" }
    follow_redirect!
    follow_redirect!

    assert_redirected_to "/fr/some/page"
    assert_equal I18n.t("errors.steam.sign_in_failed", locale: :fr), flash[:alert]
  end

  [ "https://evil.example/fr", "//evil.example/fr", "/\\evil.example", "/de/page", "fr/page", "/frx" ].each do |origin|
    test "a sign-in started from #{origin.inspect} returns home" do
      sign_in_with_steam(origin: origin)

      assert_redirected_to home_path(locale: I18n.default_locale)
    end
  end

  test "the sign-in POST without a CSRF token is refused" do
    ActionController::Base.allow_forgery_protection = true

    post "/auth/steam", params: { origin: "/en" }

    assert_redirected_to %r{/auth/failure\?message=ActionController%3A%3AInvalidAuthenticityToken}
    assert_equal 0, new_players.count
  ensure
    ActionController::Base.allow_forgery_protection = false
  end

  test "the sign-in does not start by GET" do
    get "/auth/steam"

    assert_response :not_found
    assert_equal 0, new_players.count
  end

  test "signing out resets the session and shows the sign-in button again" do
    sign_in_with_steam
    follow_redirect!
    assert_select ".status-band__counters form[action=?] input[name=_method][value=delete]", "/session?locale=en"

    delete session_path(locale: :en)

    assert_nil signed_in_player_id
    assert_redirected_to home_path(locale: :en)
    follow_redirect!
    assert_select ".status-band__counters form[action='/auth/steam'][method=post] button", "Enlist through Steam"
    assert_select ".status-band__counters form[action^='/session']", false
  end

  test "a signed-out visitor sees the Steam sign-in button as a POST form" do
    get home_path(locale: :fr)

    assert_select ".status-band__counters form[action='/auth/steam'][method=post][data-turbo=false]" do
      assert_select "input[name=origin][value='/fr']"
      assert_select "button.button--primary", "S'enrôler via Steam"
    end
  end

  test "a banned player's sign-in is refused and leaves the session as it was" do
    mock_steam("https://steamcommunity.com/openid/id/#{accounts_players(:banned).steam_id}")
    post "/auth/steam", params: { origin: "/fr" }
    session_id_before = session[:session_id]

    follow_redirect!

    assert_equal session_id_before, session[:session_id]
    assert_nil signed_in_player_id
    assert_empty registered_events
    assert_redirected_to home_path(locale: :fr)
    assert_equal I18n.t("errors.accounts.banned", locale: :fr), flash[:alert]
  end

  test "a signed-in player sees the sign-out button" do
    sign_in_with_steam
    get home_path(locale: :fr)

    assert_select ".status-band__counters form[action=?] button.button--secondary", "/session?locale=fr", text: "Quitter les rangs"
    assert_select ".status-band__counters form[action='/auth/steam']", false
  end

  # The persona name (CAP-8)

  test "a sign-in reads the player's Steam persona name and stores it" do
    calls = stub_player_summary(STEAM_ID, "Gabe")

    sign_in_with_steam

    player = new_players.sole
    assert_equal "Gabe", player.persona_name
    assert_equal player.id, signed_in_player_id
    assert_equal [ STEAM_ID ], calls.map { it["steamids"] }
  end

  test "a renamed Steam account is renamed on its next sign-in" do
    stub_player_summary(STEAM_ID, "Gabe")
    stub_player_summary(STEAM_ID, "Gaben")
    sign_in_with_steam
    assert_equal "Gabe", new_players.sole.persona_name
    delete session_path(locale: :en)

    sign_in_with_steam

    assert_equal "Gaben", new_players.sole.persona_name
  end

  [ 503, 403, :connection_failed ].each do |failure|
    test "a Steam failure (#{failure}) while reading the name signs the player in and keeps the stored name" do
      stub_player_summary(STEAM_ID, "Gabe")
      sign_in_with_steam
      delete session_path(locale: :en)
      calls = stub_player_summary_failure(failure)

      assert_no_error_reported { sign_in_with_steam }

      assert_equal 1, calls.size
      assert_equal new_players.sole.id, signed_in_player_id
      assert_equal "Gabe", new_players.sole.persona_name
      assert_redirected_to home_path(locale: :en)
      assert_equal I18n.t("sessions.create.welcome", locale: :en), flash[:notice]
    end
  end

  test "a first sign-in whose name Steam fails to give leaves none" do
    stub_player_summary_failure(503)

    sign_in_with_steam

    assert_equal new_players.sole.id, signed_in_player_id
    assert_nil new_players.sole.persona_name
  end

  test "an empty name or no player from Steam keeps the stored name" do
    stub_player_summary(STEAM_ID, "Gabe")
    stub_player_summary(STEAM_ID, "")
    stub_player_summary(STEAM_ID, nil)

    3.times do
      sign_in_with_steam
      delete session_path(locale: :en)
    end

    assert_equal "Gabe", new_players.sole.persona_name
  end

  test "an unexpected error while reading the name is reported, and the sign-in goes on" do
    steam_stubs.get(PLAYER_SUMMARIES_PATH) { raise "the summary broke" }

    assert_error_reported(RuntimeError) { sign_in_with_steam }

    assert_equal new_players.sole.id, signed_in_player_id
    assert_nil new_players.sole.persona_name
  end

  test "a banned player's name is not stored" do
    banned = accounts_players(:banned)
    stub_player_summary(banned.steam_id, "Banned Brother")
    mock_steam("https://steamcommunity.com/openid/id/#{banned.steam_id}")

    sign_in_with_steam(origin: "/fr")

    assert_nil signed_in_player_id
    assert_nil banned.reload.persona_name
  end
end

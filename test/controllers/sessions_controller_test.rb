require "test_helper"
require_relative "../support/steam_api_stubs"
require_relative "../support/steam_sign_in"

class SessionsControllerTest < ActionDispatch::IntegrationTest
  include SteamApiStubs
  include SteamSignIn

  STEAM_ID = "76561197960287930".freeze

  setup do
    mock_steam_sign_in(STEAM_ID)
    stub_steam_api
    @legal = Rails.configuration.x.legal
  end

  teardown do
    unstub_steam_api
    Rails.configuration.x.legal = @legal
  end

  def configure_legal_contact(contact_email)
    Rails.configuration.x.legal = ActiveSupport::OrderedOptions.new.update(contact_email:)
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
    assert_predicate player, :welcome_pending
    assert_nil flash[:notice], "the welcome panel takes the sign-in toast's place"
    assert flash[:signed_in], "the hub is asked to focus its first menu item"

    follow_redirect!
    assert_select "#welcome-panel"
    assert_select ".toasts[role=status] > .toast", 0
  end

  test "a returning player who closed the welcome is greeted by the toast" do
    sign_in_with_steam
    Accounts::CloseWelcome.new.call(player_id: new_players.sole.id).value!
    delete session_path(locale: :en)

    sign_in_with_steam

    assert_equal "Welcome to gameble. Your capsules are waiting.", flash[:notice]
    follow_redirect!
    assert_select ".toasts[role=status] > .toast.toast--notice .toast__message", flash[:notice]
    assert_select "#welcome-panel", 0
  end

  test "a sign-in with the visitor's motion switch on sets the account's reduced motion" do
    cookies[:motion] = "reduced"

    sign_in_with_steam

    assert_equal true, new_players.sole.reduced_motion
    assert_equal "reduced", cookies[:motion]
  end

  test "a sign-in with the switch on overrides an explicit no on a returning account" do
    sign_in_with_steam
    new_players.sole.update!(reduced_motion: false)
    delete session_path(locale: :en)
    cookies[:motion] = "reduced"

    sign_in_with_steam

    assert_equal true, new_players.sole.reduced_motion
  end

  test "a sign-in with the switch off leaves the account's setting as it was" do
    sign_in_with_steam
    new_players.sole.update!(reduced_motion: false)
    delete session_path(locale: :en)
    cookies.delete(:motion)

    sign_in_with_steam

    assert_equal false, new_players.sole.reduced_motion
  end

  test "a first sign-in without the switch leaves reduced motion on the system" do
    sign_in_with_steam

    assert_nil new_players.sole.reduced_motion
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

  test "a first sign-in, on the GET callback, creates the new player's game state row" do
    sign_in_with_steam

    player = new_players.sole
    assert_equal player.id, signed_in_player_id
    assert_equal 1, Game::PlayerState.where(player_id: player.id).count
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
    Accounts::Player.create!(steam_id: STEAM_ID)
    sign_in_with_steam(origin: "/fr")

    assert_redirected_to home_path(locale: :fr)
    assert_equal "Bienvenue sur gameble. Vos capsules vous attendent.", flash[:notice]
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
    mock_steam_sign_in("76561197960287931")

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

  [ "/fr/some/page", "/fr/library", "/fr/cards/portal", "/fr" ].each do |origin|
    test "a sign-in started on #{origin} lands on the hub in its locale" do
      Accounts::Player.create!(steam_id: STEAM_ID)
      sign_in_with_steam(origin:)

      assert_redirected_to home_path(locale: :fr)
      assert_equal I18n.t("sessions.create.welcome", locale: :fr), flash[:notice]
    end
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

  test "signing out resets the session, lands on the landing with the farewell and shows the sign-in button again" do
    sign_in_with_steam
    follow_redirect!
    assert_select "#player-menu form[action=?][data-turbo=false] input[name=_method][value=delete]", "/session?locale=en"

    delete session_path(locale: :en)

    assert_nil signed_in_player_id
    assert_redirected_to home_path(locale: :en)
    assert_equal I18n.t("sessions.destroy.farewell", locale: :en), flash[:notice]
    follow_redirect!
    assert_select ".landing-hero"
    assert_select ".toast", /#{Regexp.escape(I18n.t("sessions.destroy.farewell", locale: :en))}/
    assert_select ".top-bar__end form[action='/auth/steam'][method=post] button img[alt=?]", "Sign in through Steam (opens Steam)"
    assert_select ".top-bar form[action^='/session']", false
  end

  def session_cookie
    Array(response.headers["Set-Cookie"]).join("\n").lines.find { |cookie| cookie.start_with?("_gameble_session=") }
  end

  def session_cookie_expiry
    assert session_cookie, "the response sets the session cookie"
    expires = session_cookie[/expires=([^;\n]+)/i, 1]
    assert expires, "the session cookie outlives the browser"
    Time.httpdate(expires)
  end

  test "signing in keeps the player signed in for 30 days, in an HttpOnly cookie" do
    freeze_time
    sign_in_with_steam

    assert_in_delta 30.days.from_now, session_cookie_expiry, 1.second
    assert_match(/;\s*httponly/i, session_cookie)
    assert_match(/;\s*samesite=lax/i, session_cookie)
  end

  test "each visit pushes the end of the session 30 days further" do
    freeze_time
    sign_in_with_steam
    player_id = signed_in_player_id

    travel 20.days
    get home_path(locale: :en)

    assert_equal player_id, signed_in_player_id
    assert_in_delta 30.days.from_now, session_cookie_expiry, 1.second

    travel 30.seconds
    get legal_path(locale: :en)

    assert_in_delta 30.days.from_now, session_cookie_expiry, 1.second
  end

  test "a player away for more than 30 days is signed out" do
    sign_in_with_steam

    travel 30.days + 1.minute
    get home_path(locale: :en)

    assert_nil signed_in_player_id
    assert_response :success
    assert_select ".landing"
  end

  test "a session cookie replayed after its 30 days signs nobody in" do
    sign_in_with_steam
    expired_cookie = cookies["_gameble_session"]

    travel 30.days + 1.minute
    cookies["_gameble_session"] = expired_cookie
    get home_path(locale: :en)

    assert_nil signed_in_player_id
  end

  test "signing out ends the 30-day session at once" do
    sign_in_with_steam

    delete session_path(locale: :en)

    assert session_cookie, "the sign-out replaces the session cookie"
    assert_nil signed_in_player_id
    travel 1.day
    get home_path(locale: :en)
    assert_nil signed_in_player_id
    assert_select ".landing"
  end

  test "a signed-out visitor sees the Steam sign-in button as a POST form" do
    get how_it_works_path(locale: :fr)

    assert_select ".top-bar__end form.steam-sign-in[action='/auth/steam'][method=post][data-turbo=false]" do
      assert_select "input[name=origin][value='/fr/how-it-works']"
      assert_select "button.steam-sign-in__button img[src*='sits_01'][width='180'][height='35'][alt=?]", "Se connecter via Steam (ouvre Steam)"
    end
  end

  def record_ban(kind, at, reason: nil)
    Accounts::ModerationAction.create!(kind:, player: accounts_players(:banned), staff: accounts_players(:moderator), reason:, created_at: at)
  end

  def sign_in_banned(origin: "/fr")
    mock_steam_sign_in(accounts_players(:banned).steam_id)
    post "/auth/steam", params: { origin: }
    follow_redirect!
  end

  test "a banned player's sign-in is refused on a page that shows the moderator's reason and the contact" do
    configure_legal_contact("contact@example.test")
    record_ban(:ban, 1.day.ago, reason: "Insults in the name")
    mock_steam_sign_in(accounts_players(:banned).steam_id)
    post "/auth/steam", params: { origin: "/fr" }
    session_id_before = session[:session_id]

    follow_redirect!

    assert_response :forbidden
    assert_equal session_id_before, session[:session_id]
    assert_nil signed_in_player_id
    assert_empty registered_events
    assert_empty flash
    assert_select "html[lang=fr]"
    assert_select "title", "Compte suspendu"
    assert_select "meta[name=robots][content=noindex]"
    assert_select "main h1", "Compte suspendu"
    assert_select ".account-suspended__lead", "Ce compte a été suspendu. Vous ne pouvez plus vous connecter."
    assert_select ".account-suspended__label", "Motif indiqué par le modérateur"
    assert_select "blockquote.account-suspended__reason", "Insults in the name"
    assert_select ".account-suspended__contest", "Pour contester cette décision, écrivez à contact@example.test."
    assert_select ".account-suspended__contest a.legal__link[href=?]", "mailto:contact@example.test"
    assert_select "[style]", 0
  end

  test "the banned page names neither the player's token, id nor Steam id" do
    record_ban(:ban, 1.day.ago, reason: "Spam")
    banned = accounts_players(:banned)

    sign_in_banned

    assert_response :forbidden
    assert_no_match(/#{banned.token}|#{banned.steam_id}|\b#{banned.id}\b/, response.body)
  end

  test "a reason with markup is shown as plain text" do
    record_ban(:ban, 1.day.ago, reason: "<b>x</b> & co")

    sign_in_banned

    assert_response :forbidden
    assert_select ".account-suspended__reason", "<b>x</b> & co"
    assert_select ".account-suspended__reason b", false
  end

  test "an old ban without a reason, or with no ban recorded, offers the contact to learn the reason" do
    configure_legal_contact("contact@example.test")

    sign_in_banned
    assert_response :forbidden
    assert_select ".account-suspended__reason", false
    assert_select ".account-suspended__label", false
    assert_select ".account-suspended__contest", "Pour connaître le motif de cette suspension ou la contester, écrivez à contact@example.test."

    record_ban(:ban, 1.day.ago)
    sign_in_banned
    assert_select ".account-suspended__reason", false
    assert_select ".account-suspended__contest", /\APour connaître le motif/
  end

  test "banned again, the player reads the reason of the latest ban" do
    record_ban(:ban, 3.days.ago, reason: "Spam")
    record_ban(:unban, 2.days.ago)
    record_ban(:ban, 1.day.ago, reason: "Insults in the name")

    sign_in_banned

    assert_select ".account-suspended__reason", "Insults in the name"
  end

  test "banned from the console after an unban, the player is offered the contact only" do
    record_ban(:ban, 3.days.ago, reason: "Spam")
    record_ban(:unban, 2.days.ago)

    sign_in_banned

    assert_response :forbidden
    assert_select ".account-suspended__reason", false
    assert_select ".account-suspended__contest", /\APour connaître le motif/
  end

  test "without a contact, an English banned player is told to write to the publisher" do
    configure_legal_contact(nil)
    record_ban(:ban, 1.day.ago, reason: "Spam")

    sign_in_banned(origin: "/en")

    assert_response :forbidden
    assert_select "html[lang=en]"
    assert_select "main h1", "Account suspended"
    assert_select ".account-suspended__lead", "This account has been suspended. You can no longer sign in."
    assert_select ".account-suspended__label", "Reason given by the moderator"
    assert_select ".account-suspended__contest", "To contest this decision, write to the publisher."
    assert_select "a[href^='mailto:']", false
  end

  test "a signed-in player sees the sign-out button" do
    sign_in_with_steam
    get home_path(locale: :fr)

    assert_select "#player-menu form[action=?] button.player-menu__item", "/session?locale=fr", text: "Se déconnecter"
    assert_select ".top-bar form[action='/auth/steam']", false
  end

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

  [ 503, :connection_failed ].each do |failure|
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
      assert_nil flash[:notice], "the welcome panel still waits on the hub"
    end
  end

  test "a Steam slow to connect and to answer ends the lookup at its deadline and signs the player in without a name" do
    Steam::WebApi.player_summary_deadline = 0.1
    phases = stub_slow_player_summary(STEAM_ID, "Gabe", connect: 0.08, answer: 0.08)

    assert_no_error_reported { sign_in_with_steam }

    assert_not_includes phases, :answered
    assert_equal new_players.sole.id, signed_in_player_id
    assert_nil new_players.sole.persona_name
    assert_redirected_to home_path(locale: :en)
  end

  [ 401, 403 ].each do |status|
    test "a Steam key rejected (#{status}) while reading the name is reported once, and the sign-in keeps the stored name" do
      stub_player_summary(STEAM_ID, "Gabe")
      sign_in_with_steam
      delete session_path(locale: :en)
      stub_player_summary_failure(status)

      reports = capture_error_reports { sign_in_with_steam }

      assert_equal [ Steam::WebApi::BrokenKey ], reports.map { it.error.class }
      assert_not_includes reports.sole.error.message, API_KEY
      assert_equal new_players.sole.id, signed_in_player_id
      assert_equal "Gabe", new_players.sole.persona_name
      assert_redirected_to home_path(locale: :en)
    end
  end

  test "a missing Steam key is reported once, and the first sign-in goes on without a name" do
    Rails.configuration.x.steam.api_key = nil

    reports = capture_error_reports { sign_in_with_steam }

    assert_equal [ Steam::WebApi::BrokenKey ], reports.map { it.error.class }
    assert_equal new_players.sole.id, signed_in_player_id
    assert_nil new_players.sole.persona_name
    assert_redirected_to home_path(locale: :en)
  end

  test "a missing Steam key is reported once, and the sign-in keeps the stored name" do
    stub_player_summary(STEAM_ID, "Gabe")
    sign_in_with_steam
    delete session_path(locale: :en)
    Rails.configuration.x.steam.api_key = nil

    reports = capture_error_reports { sign_in_with_steam }

    assert_equal [ Steam::WebApi::BrokenKey ], reports.map { it.error.class }
    assert_equal new_players.sole.id, signed_in_player_id
    assert_equal "Gabe", new_players.sole.persona_name
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
    mock_steam_sign_in(banned.steam_id)

    sign_in_with_steam(origin: "/fr")

    assert_nil signed_in_player_id
    assert_nil banned.reload.persona_name
  end
end

require "test_helper"
require_relative "../support/game_packs"
require_relative "../support/steam_sign_in"
require_relative "../support/clerk_fake"

# A signed-in player arrives on the capsule screen, which offers the daily
# capsule while it waits; a player still awaiting the welcome lands on the hub.
class CapsuleLandingTest < ActionDispatch::IntegrationTest
  include ClerkFake
  include GamePacks
  include SteamSignIn

  SLOT = "section#booster section#booster-daily.booster-daily".freeze

  setup do
    @player = accounts_players(:player)
  end

  def awaiting_welcome
    @player.update!(welcome_pending: true)
  end

  test "the bare root, the PWA start, sends a signed-in player to the capsule screen in the browser's locale" do
    sign_in(@player)

    get "/", headers: { "Accept-Language" => "fr-FR,fr;q=0.9" }
    assert_redirected_to "/fr/booster"

    get "/", headers: { "Accept-Language" => "en-US,en;q=0.9" }
    assert_redirected_to "/en/booster"
  end

  test "the bare root keeps a visitor on the landing and a player awaiting the welcome on the hub" do
    get "/", headers: { "Accept-Language" => "fr-FR,fr;q=0.9" }
    assert_redirected_to "/fr"

    awaiting_welcome
    sign_in(@player)
    get "/", headers: { "Accept-Language" => "fr-FR,fr;q=0.9" }
    assert_redirected_to "/fr"
  end

  test "a Steam sign-in lands on the capsule screen, in the locale it started from, with the signed-in mark" do
    sign_in(@player, origin: "/fr")

    assert_redirected_to "/fr/booster"
    assert flash[:signed_in]
  end

  test "a Steam sign-in still awaiting the welcome lands on the hub" do
    awaiting_welcome
    sign_in(@player, origin: "/fr")

    assert_redirected_to "/fr"
  end

  test "a signed-in player opening the sign-in page goes to the capsule screen, or back to the page they named" do
    sign_in(@player)

    get sign_in_path(locale: :fr, origin: "/fr")
    assert_redirected_to "/fr/booster"

    get sign_in_path(locale: :fr, origin: "/fr/library")
    assert_redirected_to "/fr/library"

    awaiting_welcome
    get sign_in_path(locale: :fr)
    assert_redirected_to "/fr"
  end

  test "a Clerk sign-in from the hub or from nowhere lands on the capsule screen once the welcome is behind" do
    ClerkFake.install(users: { "user_mail" => ClerkFake.api_user("user_mail", accounts: [], email: "mail@example.com") })
    cookies["__session"] = ClerkFake.session_token(user_id: "user_mail")
    post clerk_session_path(locale: :en)
    assert_redirected_to "/en"

    Accounts::Player.find(session[:player_id]).update!(welcome_pending: false)
    delete session_path(locale: :en)
    cookies["__session"] = ClerkFake.session_token(user_id: "user_mail")
    post clerk_session_path(locale: :fr), params: { origin: "/fr" }
    assert_redirected_to "/fr/booster"
  end

  test "the capsule screen offers a ready daily capsule with its collect button" do
    sign_in(@player)

    get booster_path(locale: :en)

    assert_select SLOT do
      assert_select ".booster-daily__title", "Daily capsule"
      assert_select ".booster-daily__state", "Ready"
      assert_select "form[action='/en/daily-bonus'][method=post] button", "Collect"
    end
    assert_select "[data-booster-target=dailyCollected]", 0
  end

  test "the capsule screen offers no daily capsule once collected, nor without a published season" do
    Game::CollectDailyBonus.new.call(player: @player).value!
    sign_in(@player)

    get booster_path(locale: :fr)
    assert_select "#booster-daily", 0

    Game::DailyBonusClaim.delete_all
    catalog_seasons(:one).update_columns(status: "draft", published_at: nil)
    get booster_path(locale: :fr)
    assert_select "#booster-daily", 0
  end

  test "the daily capsule's words in French" do
    sign_in(@player)

    get booster_path(locale: :fr)

    assert_select "#{SLOT} .booster-daily__title", "Capsule quotidienne"
    assert_select "#{SLOT} .booster-daily__state", "Prête"
    assert_select "#{SLOT} button", "Récupérer"
  end

  test "collecting from Turbo swaps the slot for the collected mark the screen listens for, refused or not" do
    sign_in(@player)

    2.times do
      post daily_bonus_path(locale: :en), as: :turbo_stream

      assert_response :success
      assert_select "turbo-stream[action=replace][target=booster-daily] template" do
        assert_select "div#booster-daily[hidden][data-booster-target=dailyCollected]", text: ""
        assert_select ".booster-daily", 0
      end
    end
    assert_equal 1, Game::DailyBonusClaim.where(player_id: @player.id).count
  end

  test "collecting without Turbo comes back to the capsule screen" do
    sign_in(@player)

    post daily_bonus_path(locale: :en), headers: { "Referer" => booster_url(locale: :en) }

    assert_redirected_to booster_url(locale: :en)
    assert_equal 1, Game::DailyBonusClaim.where(player_id: @player.id).count
  end
end

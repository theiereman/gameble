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

require "test_helper"
require_relative "../support/counting_rate_limit"
require_relative "../support/game_packs"

# The hub's daily booster panel and its collection (CAP-16, R8): end to
# end, the result page of a bonus pack, and every refusal.
class DailyBonusesControllerTest < ActionDispatch::IntegrationTest
  include CountingRateLimit
  include GamePacks

  setup do
    Game::DrawPool.reset!
    OmniAuth.config.test_mode = true
    @player = accounts_players(:player)
  end

  teardown do
    OmniAuth.config.mock_auth.delete(:steam)
    OmniAuth.config.test_mode = false
  end

  def sign_in(player)
    OmniAuth.config.mock_auth[:steam] = OmniAuth::AuthHash.new(provider: "steam", uid: "https://steamcommunity.com/openid/id/#{player.steam_id}")
    post "/auth/steam", params: { origin: "/en" }
    follow_redirect!
    assert session[:player_id]
  end

  def reserve_badge
    css_select(".hub-menu .menu-item__badge").sole.text
  end

  def panel
    css_select(".daily-booster")
  end

  test "a player collects the bonus from the hub: one more pack, the panel gone, refused again that day, back the next" do
    now = Time.utc(2026, 10, 2, 22, 0)
    travel_to(now) do
      Game::FillBank.new.call(player: @player).value!
      Game::OpenPack.new.call(player: @player).value!
    end
    sign_in(@player)

    travel_to(now) do
      get home_path(locale: :en)
      assert_equal "9", reserve_badge
      assert_select ".daily-booster h2", "Daily booster"
      assert_select ".daily-booster form[action='/en/daily-bonus'][method=post] button", "Collect"

      post daily_bonus_path(locale: :en)

      assert_redirected_to home_path(locale: :en)
      assert_response :see_other
      assert_equal "A booster joins your reserve. The next one will be ready at midnight (UTC).", flash[:notice]
      follow_redirect!
      assert_equal "10", reserve_badge
      assert_empty panel

      post daily_bonus_path(locale: :en)

      assert_redirected_to home_path(locale: :en)
      assert_equal I18n.t("errors.game.already_collected", locale: :en), flash[:alert]
      assert_equal 1, Game::DailyBonusClaim.where(player_id: @player.id).count
    end

    travel_to(Time.utc(2026, 10, 3, 0, 0, 1)) do
      get home_path(locale: :en)
      assert_equal 1, panel.size
    end
  end

  test "with a full reserve, the panel says so and disables its button, and a collection is refused; nothing written" do
    Game::FillBank.new.call(player: @player).value!
    sign_in(@player)

    get home_path(locale: :en)
    assert_select ".daily-booster h2", "Daily booster"
    assert_select ".daily-booster .daily-booster__state", "Reserve full"
    assert_select ".daily-booster .daily-booster__text", "Open a booster to collect today's."
    assert_select ".daily-booster button[disabled]", "Collect"
    assert_select ".daily-booster form", 0

    get home_path(locale: :fr)
    assert_select ".daily-booster .daily-booster__text", "Ouvrez un booster pour récupérer celui du jour."

    assert_no_difference -> { Game::Pack.count } do
      post daily_bonus_path(locale: :fr)
    end

    assert_redirected_to home_path(locale: :fr)
    assert_equal I18n.t("errors.game.reserve_full", locale: :fr), flash[:alert]
    assert_equal 0, Game::DailyBonusClaim.count
  end

  test "the panel's copy in French" do
    sign_in(@player)

    get home_path(locale: :fr)

    assert_select ".daily-booster h2", "Booster quotidien"
    assert_select ".daily-booster .daily-booster__state", "Prêt"
    assert_select ".daily-booster .daily-booster__text", "Un booster offert chaque jour. Il rejoint votre réserve."
    assert_select ".daily-booster button", "Récupérer"
  end

  test "a visitor sees no panel, and a visitor's POST is refused with the sign-in message; nothing written" do
    get home_path(locale: :en)
    assert_empty panel

    assert_no_difference -> { Game::Pack.count } do
      assert_no_difference -> { Game::DailyBonusClaim.count } do
        post daily_bonus_path(locale: :en)
      end
    end

    assert_redirected_to home_path(locale: :en)
    assert_equal I18n.t("authorization.sign_in_required", locale: :en), flash[:alert]
  end

  test "with no season published, no panel, and a collection is refused with its message" do
    catalog_seasons(:one).update_columns(status: "draft", published_at: nil)
    sign_in(@player)

    get home_path(locale: :fr)
    assert_empty panel

    post daily_bonus_path(locale: :fr)

    assert_redirected_to home_path(locale: :fr)
    assert_equal I18n.t("errors.game.no_season", locale: :fr), flash[:alert]
    assert_equal 0, Game::DailyBonusClaim.count
  end

  test "more than 5 collections a minute by one player are sent back with their own message" do
    sign_in(@player)
    with_counting_rate_limit(DailyBonusesController) do
      5.times do
        post daily_bonus_path(locale: :en)
        assert_response :see_other
        assert_not_equal I18n.t("daily_bonuses.create.throttled", locale: :en), flash[:alert]
      end

      post daily_bonus_path(locale: :en)
    end

    assert_redirected_to home_path(locale: :en)
    assert_equal I18n.t("daily_bonuses.create.throttled", locale: :en), flash[:alert]
  end

  test "an opened bonus pack's page is titled the daily bonus, reveals its three cards, then shows them" do
    sign_in(@player)
    post daily_bonus_path(locale: :en)
    bonus = Game::Pack.where(player_id: @player.id).bonus.sole
    bonus.update_columns(available_at: 1.year.ago)
    post packs_path(locale: :en)

    assert_redirected_to "/en/packs/#{bonus.token}"
    follow_redirect!
    assert_select "h1", "Your daily bonus"
    props = JSON.parse(css_select("[data-turbo-mount-pack-reveal-props-value]").sole["data-turbo-mount-pack-reveal-props-value"])
    assert_equal 3, props["cards"].size

    get pack_path(bonus.token, locale: :fr)
    assert_select "h1", I18n.t("packs.show.heading_bonus", locale: :fr)
    assert_select ".pack-result__card .card--face", 3
  end

  test "a visitor sees no panel when no season is published, and menu 01 opens the sign-in panel" do
    catalog_seasons(:one).update_columns(status: "draft", published_at: nil)

    get home_path(locale: :en)

    assert_empty panel
    assert_select ".hub-menu button.menu-item[data-dialog-opener-dialog-value=sign-in-panel] .menu-item__label", "Open a booster"
  end
end

require "test_helper"
require_relative "../support/game_packs"

# The daily bonus panel in the attic and its collection (CAP-16, R8): end to
# end, the result page of a bonus pack, and every refusal.
class DailyBonusesControllerTest < ActionDispatch::IntegrationTest
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

  def chest_button
    css_select(".attic__object--chest .attic__chest-action button").sole
  end

  def panel
    css_select(".attic__bonus")
  end

  test "a player collects the bonus from the attic: one more pack, the panel gone, refused again that day, back the next" do
    now = Time.utc(2026, 10, 2, 22, 0)
    travel_to(now) { Game::FillBank.new.call(player: @player).value! }
    sign_in(@player)

    travel_to(now) do
      get home_path(locale: :en)
      assert_equal "Open a pack (10)", chest_button.text
      assert_select ".attic__bonus h2", "Daily bonus"
      assert_select ".attic__bonus form[action='/en/daily-bonus'][method=post] button", "Take it"

      post daily_bonus_path(locale: :en)

      assert_redirected_to home_path(locale: :en)
      assert_response :see_other
      assert_equal I18n.t("daily_bonuses.create.collected", locale: :en), flash[:notice]
      follow_redirect!
      assert_equal "Open a pack (11)", chest_button.text
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

  test "the panel's copy in French" do
    sign_in(@player)

    get home_path(locale: :fr)

    assert_select ".attic__bonus h2", "Bonus du jour"
    assert_select ".attic__bonus button", "Le prendre"
  end

  test "a visitor sees the panel with a Steam sign-in button, and a visitor's POST is refused with the sign-in message; nothing written" do
    get home_path(locale: :en)
    assert_select ".attic__bonus h2", "Daily bonus"
    assert_select ".attic__bonus form[action='/auth/steam'][method=post] button", "Enlist through Steam to take it"
    assert_select ".attic__bonus form[action='/auth/steam'] input[name=origin][value='/en']"

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
    # The test cache store counts nothing: the rate limit's store counts in
    # memory for this test.
    memory = ActiveSupport::Cache::MemoryStore.new
    store = DailyBonusesController.cache_store
    store.define_singleton_method(:increment) { |*args, **options| memory.increment(*args, **options) }
    begin
      5.times do
        post daily_bonus_path(locale: :en)
        assert_response :see_other
        assert_not_equal I18n.t("daily_bonuses.create.throttled", locale: :en), flash[:alert]
      end

      post daily_bonus_path(locale: :en)
    ensure
      store.singleton_class.remove_method(:increment)
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
    assert_select "h1", "Ton bonus du jour"
    assert_select ".pack-result__card .card--face", 3
  end

  test "a visitor sees no panel when no season is published" do
    catalog_seasons(:one).update_columns(status: "draft", published_at: nil)

    get home_path(locale: :en)

    assert_empty panel
    assert_select ".attic__chest-action form[action='/auth/steam'] button", "Enlist through Steam to open a pack"
  end

  test "in French, a visitor's chest and panel buttons say they enlist through Steam" do
    get home_path(locale: :fr)

    assert_select ".attic__chest-action form[action='/auth/steam'] button", "S'enrôler via Steam pour ouvrir un paquet"
    assert_select ".attic__bonus form[action='/auth/steam'] button", "S'enrôler via Steam pour le prendre"
  end
end

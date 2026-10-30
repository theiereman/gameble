require "test_helper"
require_relative "../support/game_sets"
require_relative "../support/steam_sign_in"

class CardBackSeasonsControllerTest < ActionDispatch::IntegrationTest
  include GameSets
  include SteamSignIn

  BACK = "set-theme-roguelike".freeze

  setup do
    @player = accounts_players(:player)
    tiers = { novice: 1, apprentice: 2, adept: 3, complete: 5 }
    @first = insert_set([], tiers, key: "roguelike", season: catalog_seasons(:one))
    @second = insert_set([], tiers, key: "roguelike", season: Catalog::Season.create!(status: :published, number: 2, published_at: Time.current))
    Game::CardBackUnlock.record(@player.id, BACK, Time.current)
    sign_in(@player)
  end

  def reach(set_id, reached_by: "trade")
    Game::SetTier.create!(player_id: @player.id, set_id:, tier: "adept", reached_by:, reached_at: Time.current)
  end

  def stored = Game::PlayerState.where(player_id: @player.id).pick(:active_card_back, :active_card_back_season)

  test "a back earned in two seasons offers a mark per season and stamps the one it wears" do
    reach(@first)
    reach(@second, reached_by: "allocation")
    patch personalization_back_path(locale: :en), params: { back: BACK, season: 1 }

    get brother_path(locale: :en, token: @player.token)

    assert_equal [ BACK, 1 ], stored
    assert_select ".back-picker__marks .back-picker__mark", 2
    assert_select ".back-picker__marks .back-picker__mark--active .season-mark", "S1"
    assert_select ".back-picker__marks button[disabled]", 1
    assert_select ".back-picker__stamped .season-mark", "S1"
    assert_select ".back-picker__grid .season-mark", false
    assert_select "[style]", false
  end

  test "choosing another season of the active back changes the mark" do
    reach(@first)
    reach(@second, reached_by: "allocation")
    patch personalization_back_path(locale: :en), params: { back: BACK, season: 1 }

    patch personalization_back_path(locale: :en), params: { back: BACK, season: 2 }

    assert_redirected_to brother_path(locale: :en, token: @player.token)
    assert_equal [ BACK, 2 ], stored
  end

  test "a back earned once shows no mark choice and no stamp" do
    reach(@first)
    patch personalization_back_path(locale: :en), params: { back: BACK }

    get brother_path(locale: :en, token: @player.token)

    assert_equal [ BACK, nil ], stored
    assert_select ".back-picker__marks", false
    assert_select "#profile-back-dialog .season-mark", false
  end

  test "a forged season is refused and the choice does not change" do
    reach(@first)
    reach(@second, reached_by: "allocation")
    patch personalization_back_path(locale: :en), params: { back: BACK, season: 1 }

    patch personalization_back_path(locale: :en), params: { back: BACK, season: 9 }

    assert_response :see_other
    assert_equal "You did not earn this card back in that season.", flash[:alert]
    assert_equal [ BACK, 1 ], stored
  end

  test "the booster screen of an opened pack carries the season its back wore" do
    pack = Game::Pack.create!(player_id: @player.id, kind: "regular", season_id: catalog_seasons(:one).id, card_season_ids: Array.new(5, catalog_card_seasons(:portal_one).id),
      available_at: 1.minute.ago, opened_at: 1.minute.ago, card_back: BACK, card_back_season: 2)

    get booster_path(locale: :en, pack: pack.token)

    assert_select "template[data-booster-target=pack][data-card-back='#{BACK}'][data-card-back-season='2']"
  end

  test "a pack opened with a back that wore no season carries none" do
    pack = Game::Pack.create!(player_id: @player.id, kind: "regular", season_id: catalog_seasons(:one).id, card_season_ids: Array.new(5, catalog_card_seasons(:portal_one).id),
      available_at: 1.minute.ago, opened_at: 1.minute.ago, card_back: BACK)

    get booster_path(locale: :en, pack: pack.token)

    assert_select "template[data-booster-target=pack]:not([data-card-back-season])"
  end
end

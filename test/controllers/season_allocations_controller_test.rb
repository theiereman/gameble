require "test_helper"
require_relative "../support/counting_rate_limit"
require_relative "../support/second_season"
require_relative "../support/steam_sign_in"

class SeasonAllocationsControllerTest < ActionDispatch::IntegrationTest
  include CountingRateLimit
  include SecondSeason
  include SteamSignIn

  setup do
    @player = accounts_players(:player)
    @season, @set = publish_second_season(@player)
  end

  def seen_season = Game::PlayerState.find_by!(player_id: @player.id).allocation_seen_season

  test "a visitor is sent to sign in and is never redirected to the screen" do
    get season_allocation_path(locale: :en)
    assert_response :redirect
    assert_no_match(/season-allocation\z/, response.location)

    get home_path(locale: :en)
    assert_response :success
  end

  test "the hub and the booster page lead a pending player to the screen" do
    sign_in(@player)

    get home_path(locale: :en)
    assert_redirected_to season_allocation_path(locale: :en)

    get booster_path(locale: :en)
    assert_redirected_to season_allocation_path(locale: :en)
  end

  test "the screen renders the title and the carried tiers in both locales, without ids or a sentence under the title" do
    sign_in(@player)

    get season_allocation_path(locale: :en)

    assert_response :success
    assert_select "h1", "ALLOCATION · SEASON 2"
    assert_select ".allocation-section__title", text: "Your tiers in the next season"
    assert_select ".allocation-row", 3
    assert_select ".allocation__title + p", 0
    assert_no_match(/data-id|\bid="\d+"/, response.body)

    get season_allocation_path(locale: :fr)

    assert_select "h1", "ALLOCATION · SAISON 2"
    assert_select "button", text: "Continuer"
  end

  test "the screen shows the achievements earned in the ended season and omits the section when there are none" do
    sign_in(@player)
    get season_allocation_path(locale: :en)
    assert_select "#allocation-unlocked-heading", 0

    Game::AchievementUnlock.record(@player.id, :first_booster, 1.day.ago)
    get season_allocation_path(locale: :fr)

    assert_select "#allocation-unlocked-heading", "Débloqué pendant la saison 1"
    assert_select ".allocation-row__name b", text: I18n.t("achievements.names.first_booster", locale: :fr)
  end

  test "the screen shows the card backs earned in the ended season, each with its picture, name, condition and date, and names no id" do
    Catalog::Season.find_by!(number: 1).update!(published_at: 10.days.ago)
    @season.update!(published_at: 1.hour.ago)
    Game::CardBackUnlock.record(@player.id, Game::CardBacks.set_key("theme", "horror"), 3.days.ago)
    Game::CardBackUnlock.record(@player.id, Game::CardBacks::GOAL_BACK, 20.days.ago)
    sign_in(@player)

    get season_allocation_path(locale: :en)

    assert_select "#allocation-unlocked-heading", "Unlocked in season 1"
    assert_select ".allocation-row--back", 1
    assert_select ".allocation-row--back img[src*='back-theme-horror-m']", 1
    assert_select ".allocation-row--back .allocation-row__name b", text: /\S/
    assert_select ".allocation-row--back .allocation-row__how", text: /\ACollect half of the .+ set\.\z/
    assert_select ".allocation-row--back time", 1
    assert_no_match(/data-id|\bid="\d+"/, response.body)

    get season_allocation_path(locale: :fr)

    assert_select ".allocation-section__sub", text: /Dos de carte/
  end

  test "the screen writes nothing" do
    sign_in(@player)

    assert_no_difference [ "Game::SetTier.count", "Game::PlayerState.where(allocation_seen_season: 2).count" ] do
      get season_allocation_path(locale: :en)
    end
  end

  test "continuing marks the season seen and leads to the hub, which no longer redirects" do
    sign_in(@player)

    post season_allocation_path(locale: :en)

    assert_redirected_to home_path(locale: :en)
    assert_equal 2, seen_season
    get home_path(locale: :en)
    assert_response :success
    get season_allocation_path(locale: :en)
    assert_redirected_to home_path(locale: :en)
  end

  test "a player without an earlier card goes straight to the hub" do
    Game::Holding.where(player_id: @player.id).delete_all
    sign_in(@player)

    get home_path(locale: :en)
    assert_response :success

    get season_allocation_path(locale: :en)
    assert_redirected_to home_path(locale: :en)
  end

  test "continuing is throttled per player and sends the thirty-first attempt back with an alert" do
    sign_in(@player)

    with_counting_rate_limit(SeasonAllocationsController) do
      30.times do
        post season_allocation_path(locale: :en)
        assert_not_equal I18n.t("season_allocations.create.throttled", locale: :en), flash[:alert]
      end

      post season_allocation_path(locale: :en)
    end

    assert_redirected_to season_allocation_path(locale: :en)
    assert_equal I18n.t("season_allocations.create.throttled", locale: :en), flash[:alert]
  end

  test "a failed marking keeps the screen and shows the alert" do
    sign_in(@player)
    failing = Object.new.tap { |operation| operation.define_singleton_method(:call) { |**| Dry::Monads::Failure(:unavailable) } }
    original = Game::MarkAllocationSeen.method(:new)
    Game::MarkAllocationSeen.define_singleton_method(:new) { |*| failing }
    begin
      post season_allocation_path(locale: :en)
    ensure
      Game::MarkAllocationSeen.define_singleton_method(:new, original)
    end

    assert_redirected_to season_allocation_path(locale: :en)
    assert_equal 1, seen_season
    assert_equal I18n.t("season_allocations.create.failed", locale: :en), flash[:alert]
  end

  test "a player without a state row is led to the screen, which renders, and continuing creates the row" do
    sign_in(@player)
    Game::PlayerState.where(player_id: @player.id).delete_all

    get season_allocation_path(locale: :en)
    assert_response :success
    assert_select ".allocation-row", 3

    post season_allocation_path(locale: :en)
    assert_redirected_to home_path(locale: :en)
    assert_equal 2, seen_season
  end

  test "only page navigations are led to the screen, not a Turbo Frame, a JSON read or a HEAD request" do
    sign_in(@player)

    get home_path(locale: :en), headers: { "Turbo-Frame" => "panel" }
    assert_response :success

    get booster_path(locale: :en, format: :json)
    assert_response :success

    head home_path(locale: :en)
    assert_response :success
  end

  test "the booster page no longer redirects once the season is seen" do
    sign_in(@player)
    post season_allocation_path(locale: :en)

    get booster_path(locale: :en)

    assert_response :success
  end

  test "continuing when nothing is pending changes nothing and leads to the hub" do
    Game::Holding.where(player_id: @player.id).delete_all
    sign_in(@player)

    assert_no_difference "Game::SetTier.count" do
      post season_allocation_path(locale: :en)
    end

    assert_redirected_to home_path(locale: :en)
  end

  test "the section of the ended season lists its tiers with no season mark or season count on a tier" do
    ended = Catalog::Season.find_by!(number: 1)
    old_set = Catalog::Set.find_by(season_id: ended.id) ||
      Catalog::Set.find(Catalog::Set.insert_all!([ { season_id: ended.id, kind: "theme", key: "old", params: { "theme" => "old" } } ], returning: :id).rows.flatten.sole)
    now = Time.current
    Game::SetTier.insert_all!([ { player_id: @player.id, set_id: old_set.id, tier: "bronze", held: 1, reached_by: "trade", reached_at: 1.day.ago, created_at: now, updated_at: now } ])
    sign_in(@player)

    get season_allocation_path(locale: :en)

    assert_select "#allocation-earned-heading", "Earned in season 1"
    assert_select "[aria-labelledby=allocation-earned-heading] .allocation-row", 1
    assert_select ".allocation-row [class*='season']", 0
    assert_select ".allocation-row", text: /\bseasons?\b/i, count: 0
  end
end

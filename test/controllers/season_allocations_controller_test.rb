require "test_helper"
require_relative "../support/second_season"
require_relative "../support/steam_sign_in"

class SeasonAllocationsControllerTest < ActionDispatch::IntegrationTest
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
  end
end

require "test_helper"
require_relative "../../support/catalog_seeds"
require_relative "../../support/game_sets"

# Game::SetsInProgress: every set of the season a player has started,
# measured in one statement.
class Game::SetsInProgressTest < ActiveSupport::TestCase
  include CatalogSeeds
  include GameSets

  setup do
    @player = accounts_players(:player)
    @season, @cards = published_cards(30)
  end

  def standings(player = @player, season: @season) = Game::SetsInProgress.call(player, season:)

  test "each started set: the games held, its size, its tiers, and none of the sets not started" do
    roguelike = insert_theme(@cards.first(20), key: "roguelike", season: @season)
    valve = insert_set(@cards[20, 3], { complete: 3 }, kind: "studio", key: "valve", params: { "studio" => "Valve" }, season: @season)
    untouched = insert_theme(@cards[23, 5], key: "horror", season: @season)
    hold_all(@player, @cards.first(3) + [ @cards[21] ])
    hold_all(@player, [ @cards[3] ], quantity: 0)

    result = standings
    assert_equal [ roguelike, valve ].sort, result.keys.sort
    assert_not_includes result.keys, untouched
    assert_equal [ 3, 20, { "bronze" => 2, "silver" => 5, "gold" => 10, "complete" => 20 } ], result.fetch(roguelike).then { [ it.held, it.total, it.tiers ] }
    assert_equal [ 1, 3, { "complete" => 3 } ], result.fetch(valve).then { [ it.held, it.total, it.tiers ] }
    assert_equal "bronze", result.fetch(roguelike).reached_tier
  end

  test "a game held only in an earlier edition counts in the published season's set" do
    portal_two = Catalog::CardSeason.insert_all!([ { card_id: catalog_cards(:portal).id, season_id: @season.id, prestige_score: 0.9, rating: 95 } ],
      returning: :id).rows.flatten.sole
    set = insert_theme([ portal_two, @cards.first ], key: "puzzle", season: @season)
    Game::Holding.create!(player_id: @player.id, card_season_id: catalog_card_seasons(:portal_one).id, quantity: 2)

    assert_equal 1, standings.fetch(set).held
    assert_empty standings(season: catalog_seasons(:one)).keys - [ catalog_sets(:valve_one).id ]
  end

  test "the sets the latest gain touched, and those a tier was recorded for at that gain" do
    latest = Time.utc(2026, 10, 17, 12, 0, 0.5r)
    touched = insert_theme(@cards.first(10), key: "roguelike", season: @season)
    raised = insert_theme(@cards[10, 10], key: "rpg", season: @season)
    older = insert_theme(@cards[20, 10], key: "horror", season: @season)
    hold_all(@player, [ @cards[0] ], gained_at: latest)
    hold_all(@player, [ @cards[10] ], gained_at: latest)
    hold_all(@player, [ @cards[11], @cards[20] ], gained_at: latest - 1.hour)
    hold_all(@player, [ @cards[21] ])
    Game::SetTier.insert_all!([ { player_id: @player.id, set_id: raised, tier: "bronze", reached_by: "trade", reached_at: latest, created_at: latest, updated_at: latest },
      { player_id: @player.id, set_id: older, tier: "bronze", reached_by: "trade", reached_at: latest - 1.hour, created_at: latest, updated_at: latest } ])

    result = standings
    assert_equal [ true, false ], result.fetch(touched).then { [ it.just, it.reached_now ] }
    assert_equal [ true, true ], result.fetch(raised).then { [ it.just, it.reached_now ] }
    assert_equal [ false, false ], result.fetch(older).then { [ it.just, it.reached_now ] }
    assert_equal latest, result.fetch(raised).gained_at
    assert_equal latest - 1.hour, result.fetch(older).gained_at
  end

  test "holdings never timed touch nothing" do
    set = insert_theme(@cards.first(10), key: "roguelike", season: @season)
    hold_all(@player, @cards.first(2))

    standing = standings.fetch(set)
    assert_equal [ false, false, nil ], [ standing.just, standing.reached_now, standing.gained_at ]
  end

  test "one query whatever the sets started; none for a visitor or no season" do
    6.times { |index| insert_theme(@cards[index * 5, 5], key: "theme-#{index}", season: @season) }
    hold_all(@player, @cards.first(30))

    assert_queries_count(1) { assert_equal 6, standings.size }
    assert_queries_count(0) { assert_equal({}, standings(nil)) }
    assert_queries_count(0) { assert_equal({}, standings(season: nil)) }
  end
end

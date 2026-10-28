require "test_helper"
require_relative "../../support/catalog_seeds"
require_relative "../../support/game_sets"

class Game::ProfileTitlesTest < ActiveSupport::TestCase
  include CatalogSeeds
  include GameSets

  setup do
    @player = accounts_players(:player)
    @season, @cards = published_cards(5)
    @valve = insert_valve(@season)
  end

  def insert_valve(season) = insert_set(@cards, { novice: 1, adept: 3, complete: 5 }, kind: "studio", key: "valve", params: { "studio" => "Valve" }, season:)

  def reach(set_id, *tiers, player: @player)
    Game::SetTier.insert_all!(tiers.map { |tier| { player_id: player.id, set_id:, tier:, reached_by: "trade", reached_at: Time.current } })
  end

  def titles(player = @player) = Game::ProfileTitles.call(player)

  test "a title for each tier and the completion of a set, highest rank first, in one query" do
    reach(@valve, "novice", "adept", "complete")

    result = nil
    assert_queries_count(1) { result = titles }

    assert_equal %w[complete adept novice], result.map(&:rank)
    assert_equal [ [ "studio", "valve", { "studio" => "Valve" } ] ], result.map { [ it.kind, it.key, it.params ] }.uniq
  end

  test "bronze, silver and gold give the titles of apprentice, adept and master" do
    reach(@valve, "bronze", "silver", "gold")

    assert_equal %w[master adept apprentice], titles.map(&:rank)
  end

  test "a legacy bronze and a later apprentice of the same set give one title" do
    later = published_cards(5).first
    reach(@valve, "bronze")
    reach(insert_valve(later), "apprentice")

    result = titles
    assert_equal [ "apprentice" ], result.map(&:rank)
    assert_equal later.number, result.sole.season_number
  end

  test "a set reached in two seasons shows the latest season it was earned in" do
    later = published_cards(5).first
    reach(@valve, "novice")
    reach(insert_valve(later), "novice")

    assert_equal [ later.number ], titles.map(&:season_number)
  end

  test "another player's tiers and a player with none give no title" do
    reach(@valve, "novice", player: accounts_players(:moderator))

    assert_empty titles
  end
end

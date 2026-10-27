require "test_helper"
require_relative "../../support/catalog_seeds"
require_relative "../../support/holdings"

# Game::CollectionSummary: a player's games, in any edition, and the
# season's sets they complete.
class Game::CollectionSummaryTest < ActiveSupport::TestCase
  include Holdings
  include CatalogSeeds

  setup do
    @season = publish_sets_draft
    @sets = Catalog::Set.where(season_id: @season.id).index_by(&:key)
    @player = accounts_players(:player)
  end

  def members(key)
    Catalog::SetMembership.where(set_id: @sets.fetch(key).id).order(:position).pluck(:card_season_id)
  end

  def summary(player = @player)
    Game::CollectionSummary.call(player, season: @season)
  end

  test "the distinct cards held in the season and the sets complete, in one query" do
    members("pirates").each_with_index { |id, index| hold(@player, id, index + 1) }
    extra = (members("rpg") - members("pirates")).first
    hold(@player, extra, 1)
    hold(@player, (members("horror") - members("pirates")).first, 0)
    hold(accounts_players(:moderator), members("ufos").first, 1)

    result = nil
    assert_queries_count(1) { result = summary }
    complete = @sets.keys.count { |key| (members(key) - members("pirates") - [ extra ]).empty? }
    assert_equal 1, complete
    assert_equal Game::CollectionSummary::Summary.new(distinct_cards: 9, complete_sets: complete), result
  end

  test "a game held only in another season's edition counts" do
    hold(@player, catalog_card_seasons(:portal_one).id, 1)

    assert_equal Game::CollectionSummary::Summary.new(distinct_cards: 1, complete_sets: 0), summary
  end

  test "a set completes with a member's game held in another edition only" do
    pirates = members("pirates")
    reprint = Catalog::Season.create!(status: :draft, number: Catalog::Season.next_number)
    old = Catalog::CardSeason.find(pirates.first)
    other = Catalog::CardSeason.create!(card_id: old.card_id, season: reprint, prestige_score: 0.5, rating: 90, rarity: :rare)
    hold(@player, other.id, 1)
    pirates.drop(1).each { hold(@player, it, 1) }

    assert_equal Game::CollectionSummary::Summary.new(distinct_cards: pirates.size, complete_sets: 1), summary
  end

  test "a set without members is never complete" do
    season = seed_published_sets([ [ "studio", "empty", { "studio" => "Empty" } ] ])

    assert_equal 0, Game::CollectionSummary.call(@player, season:).complete_sets
  end

  test "every set complete" do
    Game::Holding.insert_all!(Catalog::CardSeason.where(season_id: @season.id).ids.map { { player_id: @player.id, card_season_id: it, quantity: 1 } })

    assert_equal Game::CollectionSummary::Summary.new(distinct_cards: 150, complete_sets: @sets.size), summary
  end

  test "zeros, without a query, for a visitor or no season" do
    assert_queries_count(0) { assert_equal Game::CollectionSummary::Summary.new(distinct_cards: 0, complete_sets: 0), Game::CollectionSummary.call(nil) }
    assert_queries_count(0) { assert_equal 0, Game::CollectionSummary.call(@player, season: nil).distinct_cards }
  end

  test "without a season given, the published one is looked up: two queries" do
    hold(@player, members("pirates").first, 1)

    result = nil
    assert_queries_count(2) { result = Game::CollectionSummary.call(@player) }
    assert_equal 1, result.distinct_cards
  end
end

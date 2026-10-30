require "test_helper"
require_relative "../../support/holdings"

class Game::RarityLegendTest < ActiveSupport::TestCase
  include Holdings
  setup do
    @player = accounts_players(:player)
  end

  def season(number, status: :published)
    Catalog::Season.create!(status:, number:, published_at: (Time.current if status == :published))
  end

  def edition(name, season:, rarity:)
    one = catalog_card_seasons(name)
    Catalog::CardSeason.insert_all!([ { card_id: one.card_id, season_id: season.id, prestige_score: one.prestige_score, rating: one.rating,
      rarity:, number: one.number } ], returning: :id).rows.flatten.sole
  end

  def figures(row) = [ row.season.owned, row.season.total, row.overall.owned, row.overall.total ]

  def legend_row(rarity) = Game::RarityLegend.call(@player).rows.find { it.rarity == rarity }

  test "the published season is the highest one; overall, a game counts once whatever its editions, over every published season" do
    two = season(2)
    hold(@player, edition(:portal_one, season: two, rarity: "epic"))
    edition(:rare_card_one, season: two, rarity: "epic")
    edition(:legendary_card_one, season: season(3, status: :draft), rarity: "epic")
    hold(@player, catalog_card_seasons(:portal_one).id)

    assert_equal [ 1, 2, 1, 2 ], figures(legend_row(:epic))
    assert_equal [ 0, 0, 0, 1 ], figures(legend_row(:common))
  end

  test "a game held in two rarities counts in each, and once in the totals, which then match the unique cards counter" do
    hold(@player, edition(:portal_one, season: season(2), rarity: "legendary"))
    hold(@player, catalog_card_seasons(:portal_one).id)
    hold(@player, catalog_card_seasons(:common_card_one).id)

    legend = Game::RarityLegend.call(@player)

    assert_equal [ 0, 0, 1, 1 ], figures(legend.rows.find { it.rarity == :epic })
    assert_equal [ 1, 1, 1, 2 ], figures(legend.rows.find { it.rarity == :legendary })
    assert_equal 6, legend.rows.sum { it.overall.total }
    assert_equal [ 1, 1, 2, 5 ], figures(legend.totals)
    assert_equal Game::HeldGames.count(@player), legend.totals.overall.owned
  end

  test "an edition held in several copies counts once" do
    hold(@player, catalog_card_seasons(:common_card_one).id, 3)

    assert_equal [ 1, 1, 1, 1 ], figures(legend_row(:common))
  end

  test "an edition with no copy left is not owned, and still counts in the totals" do
    hold(@player, catalog_card_seasons(:rare_card_one).id, 0)

    assert_equal [ 0, 1, 0, 1 ], figures(legend_row(:rare))
  end

  test "a draft season counts in neither total" do
    draft = season(2, status: :draft)
    hold(@player, edition(:legendary_card_one, season: draft, rarity: "legendary"))

    assert_equal [ 0, 1, 0, 1 ], figures(legend_row(:legendary))
  end

  test "an edition with no rarity counts nowhere" do
    unrated = edition(:uncommon_card_one, season: season(2), rarity: nil)
    hold(@player, unrated)

    assert_equal([ [ 0, 0, 0, 1 ] ] * 5, Game::RarityLegend.call(@player).rows.map { figures(it) })
  end

  test "another player's editions never count" do
    hold(accounts_players(:moderator), catalog_card_seasons(:uncommon_card_one).id)

    assert_equal [ 0, 1, 0, 1 ], figures(legend_row(:uncommon))
  end

  test "with no published season every figure is zero, and every rarity still has its row" do
    catalog_seasons(:one).update_columns(status: "draft")
    hold(@player, catalog_card_seasons(:portal_one).id)

    legend = Game::RarityLegend.call(@player)

    assert_equal Catalog::Rarity::TIERS.values, legend.rows.map(&:rarity)
    assert_equal([ [ 0, 0, 0, 0 ] ] * 5, legend.rows.map { figures(it) })
    assert_equal [ 0, 0, 0, 0 ], figures(legend.totals)
  end

  test "the rows in rarity order, and the totals counting each game once, in one query" do
    hold(@player, catalog_card_seasons(:portal_one).id, 2)
    hold(@player, catalog_card_seasons(:common_card_one).id)
    hold(@player, edition(:rare_card_one, season: season(2), rarity: "legendary"))

    legend = nil
    assert_queries_count(1) { legend = Game::RarityLegend.call(@player) }

    assert_equal %i[common uncommon rare epic legendary], legend.rows.map(&:rarity)
    assert_equal [ [ 0, 0, 1, 1 ], [ 0, 0, 0, 1 ], [ 0, 0, 0, 1 ], [ 0, 0, 1, 1 ], [ 1, 1, 1, 2 ] ], legend.rows.map { figures(it) }
    assert_equal [ 1, 1, 3, 5 ], figures(legend.totals)
    assert_nil legend.totals.rarity
  end
end

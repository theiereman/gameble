require "test_helper"
require_relative "../../support/holdings"

# Game::HeldEditions: the editions of a game a player holds, for the card
# detail's copies and editions.
class Game::HeldEditionsTest < ActiveSupport::TestCase
  include Holdings
  setup do
    @player = accounts_players(:player)
    @portal = catalog_card_seasons(:portal_one)
  end

  def edition(number, rarity:)
    season = Catalog::Season.create!(status: :published, number:, published_at: Time.current)
    Catalog::CardSeason.insert_all!([ { card_id: @portal.card_id, season_id: season.id, prestige_score: 0.5, rating: 90, rarity: } ],
      returning: :id).rows.flatten.sole
  end

  test "each edition held: its rarity, season and copies, the best rarity first, then by season, in one query" do
    hold(@player, edition(4, rarity: "rare"), 2)
    hold(@player, @portal.id, 1)
    hold(@player, edition(3, rarity: "legendary"), 1)
    hold(@player, edition(2, rarity: "rare"), 3)
    hold(@player, edition(5, rarity: "common"), 0)
    hold(@player, catalog_card_seasons(:rare_card_one).id, 1)
    hold(accounts_players(:moderator), @portal.id, 1)

    editions = nil
    assert_queries_count(1) { editions = Game::HeldEditions.call(@player, card_id: @portal.card_id) }
    assert_equal [ [ "legendary", 3, 1 ], [ "epic", 1, 1 ], [ "rare", 2, 3 ], [ "rare", 4, 2 ] ], editions
  end

  test "none for a game not held, and for a visitor without a query" do
    assert_equal [], Game::HeldEditions.call(@player, card_id: @portal.card_id)
    assert_queries_count(0) { assert_equal [], Game::HeldEditions.call(nil, card_id: @portal.card_id) }
  end
end

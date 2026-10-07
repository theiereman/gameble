require "test_helper"
require_relative "../../support/catalog_seeds"

# Game::CollectionStates (CAP-6, story 10.7): the state filter of the
# collection grid and its newest-first order.
class Game::CollectionStatesTest < ActiveSupport::TestCase
  include CatalogSeeds

  setup do
    @season = publish_sets_draft
    @player = accounts_players(:player)
    @cards = Catalog::CardSeason.where(season_id: @season.id).where.not(rarity: nil).order(:number, :id)
    @a, @b, @c, @d = @cards.ids.first(4)
    Game::Holding.create!(player_id: @player.id, card_season_id: @a, quantity: 1, last_gained_at: 3.hours.ago)
    Game::Holding.create!(player_id: @player.id, card_season_id: @b, quantity: 2, last_gained_at: 1.hour.ago)
    Game::Holding.create!(player_id: @player.id, card_season_id: @c, quantity: 1)
    Game::Holding.create!(player_id: @player.id, card_season_id: @d, quantity: 0)
    Game::PlayerState.where(player_id: @player.id).update_all(collection_seen_up_to: 2.hours.ago)
  end

  def ids(states, player: @player, newest_first: false)
    Game::CollectionStates.call(player, @cards, states:, newest_first:).pluck(:id)
  end

  test "no state is the owned cards; a held card at zero copies is not owned" do
    assert_equal [ @a, @b, @c ], ids([])
    assert_equal [ @a, @b, @c ], ids(%w[owned])
  end

  test "missing is every other card, all is every card" do
    assert_equal @cards.ids - [ @a, @b, @c ], ids(%w[missing])
    assert_equal 150, ids(%w[all]).size
    assert_equal 150, ids(%w[all owned]).size
  end

  test "new is gained after the watermark; duplicates is two copies or more; states are an OR" do
    assert_equal [ @b ], ids(%w[new])
    assert_equal [ @b ], ids(%w[duplicates])
    assert_equal ([ @b ] + (@cards.ids - [ @a, @b, @c ])).sort, ids(%w[new missing]).sort
  end

  test "newest first: by last gain, the never gained and the unheld after, then by number" do
    assert_equal [ @b, @a, @c ], ids(%w[owned], newest_first: true)
    assert_equal [ @b, @a, @c, @d ], ids(%w[all], newest_first: true).first(4)
  end

  test "newest first keeps every held card before the unheld, whatever its number" do
    late = @cards.ids.last
    Game::Holding.create!(player_id: @player.id, card_season_id: late, quantity: 1)
    assert_equal [ @b, @a, @c, late ], ids(%w[all], newest_first: true).first(4)
  end

  test "unknown states are ignored and sanitized in order" do
    assert_equal [ @a, @b, @c ], ids(%w[bogus])
    assert_equal %w[owned missing], Game::CollectionStates.sanitize(%w[missing nope owned owned])
  end

  test "a visitor holds nothing: only missing and all match, with no holdings query" do
    assert_no_queries_match(/game_holdings/) do
      assert_empty ids(%w[owned], player: nil)
      assert_empty ids(%w[new], player: nil)
      assert_empty ids(%w[duplicates], player: nil)
      assert_equal 150, ids(%w[missing], player: nil).size
      assert_equal 150, ids(%w[all], player: nil, newest_first: true).size
    end
  end

  test "another player's holdings do not count" do
    assert_empty ids([], player: accounts_players(:moderator))
    assert_equal 150, ids(%w[missing], player: accounts_players(:moderator)).size
  end
end

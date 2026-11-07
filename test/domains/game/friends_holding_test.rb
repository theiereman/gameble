require "test_helper"
require_relative "../../support/game_sets"
require_relative "../../support/holdings"

class Game::FriendsHoldingTest < ActiveSupport::TestCase
  include GameSets
  include Holdings

  setup do
    @player = accounts_players(:player)
    @lea = accounts_players(:moderator)
    @max = accounts_players(:administrator)
    @portal = catalog_card_seasons(:portal_one)
    [ @lea, @max ].each { befriend(it) }
  end

  def befriend(friend)
    low, high = [ @player.id, friend.id ].minmax
    Game::Friendship.create!(low_player_id: low, high_player_id: high)
  end

  def holders
    Game::FriendsHolding.call(@player, card_id: @portal.card_id, card_season_id: @portal.id)
  end

  test "a friend with a single free copy is listed" do
    hold(@lea, @portal.id, 1)

    assert_equal [ @lea.id ], holders.map { it.player.id }
    assert_equal [ 1 ], holders.map(&:copies)
    assert_equal [ @portal.id ], holders.map(&:card_season_id)
  end

  test "friends with more free copies come first" do
    hold(@lea, @portal.id, 1)
    hold(@max, @portal.id, 3, reserved: 1)

    assert_equal [ @max.id, @lea.id ], holders.map { it.player.id }
  end

  test "a copy reserved in a trade is not free" do
    hold(@lea, @portal.id, 1, reserved: 1)

    assert_empty holders
  end

  test "a private friend is never listed" do
    hold(@lea, @portal.id, 2)
    @lea.update_columns(visibility: "private")

    assert_empty holders
  end

  test "nobody is listed to a private player" do
    hold(@lea, @portal.id, 2)
    @player.update_columns(visibility: "private")

    assert_empty holders
  end

  test "a friend already asked for the card comes last and is marked" do
    hold(@lea, @portal.id, 5)
    hold(@max, @portal.id, 1)
    Game::ProposeTrade.new.call(player: @player, recipient: @lea, offer: {}, request: { @portal.id => 1 }).value!

    assert_equal [ @max.id, @lea.id ], holders.map { it.player.id }
    assert_equal [ false, true ], holders.map(&:asked)
  end

  test "an expired request, a closed one, or one for another card does not mark the friend as asked" do
    hold(@lea, @portal.id, 2)
    other = catalog_card_seasons(:common_card_one)
    hold(@lea, other.id, 2)
    Game::ProposeTrade.new.call(player: @player, recipient: @lea, offer: {}, request: { other.id => 1 }).value!
    assert_equal [ false ], holders.map(&:asked)

    trade = Game::ProposeTrade.new.call(player: @player, recipient: @lea, offer: {}, request: { @portal.id => 1 }).value!
    trade = trade.respond_to?(:update_columns) ? trade : Game::Trade.order(:id).last
    assert_equal [ true ], holders.map(&:asked)

    trade.update_columns(expires_at: 1.day.ago)
    assert_equal [ false ], holders.map(&:asked)

    trade.update_columns(expires_at: 1.day.from_now, status: "declined")
    assert_equal [ false ], holders.map(&:asked)
  end

  test "a stranger who holds the card is not listed" do
    stranger = accounts_players(:banned)
    hold(stranger, @portal.id, 2)

    assert_empty holders
  end

  test "a trade the friend proposed, or one with an offer, does not mark the friend as asked" do
    hold(@lea, @portal.id, 2)
    hold(@max, @portal.id, 2)
    hold(@player, catalog_card_seasons(:common_card_one).id, 1)
    Game::ProposeTrade.new.call(player: @lea, recipient: @player, offer: { @portal.id => 1 }, request: { catalog_card_seasons(:common_card_one).id => 1 }).value!
    Game::ProposeTrade.new.call(player: @player, recipient: @max, offer: { catalog_card_seasons(:common_card_one).id => 1 }, request: { @portal.id => 1 }).value!

    assert_equal [ false, false ], holders.map(&:asked)
  end

  test "the shown edition is requested when the friend has a free copy of it, else the one with most copies" do
    season = seed_published_sets([ [ "theme", "puzzle", { "theme" => "puzzle" } ] ])
    other_id = Catalog::CardSeason.insert_all!([ { card_id: @portal.card_id, season_id: season.id, prestige_score: 0.99, rating: 99, rarity: 5, number: 1 } ],
      returning: :id).rows.flatten.first
    other = Catalog::CardSeason.find(other_id)
    hold(@lea, other.id, 3)
    assert_equal [ other.id ], holders.map(&:card_season_id)

    hold(@lea, @portal.id, 1)
    assert_equal [ @portal.id ], holders.map(&:card_season_id)
  end
end

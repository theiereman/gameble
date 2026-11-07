require "test_helper"
require_relative "../../support/holdings"

# Whether given cards of one holder are still spared for one other player:
# any free copy (or a minimum of free copies), and the game on no open trade between the two.
class Game::TradeSuggestionSparesTest < ActiveSupport::TestCase
  include Holdings

  setup do
    @player = accounts_players(:player)
    @lea = accounts_players(:moderator)
    @max = accounts_players(:administrator)
    [ @lea, @max ].each { befriend(it) }
    @portal = catalog_card_seasons(:portal_one).id
    @soldier = catalog_card_seasons(:common_card_one).id
    @hills = catalog_card_seasons(:uncommon_card_one).id
    @depths = catalog_card_seasons(:rare_card_one).id
  end

  def befriend(friend)
    low, high = [ @player.id, friend.id ].minmax
    Game::Friendship.create!(low_player_id: low, high_player_id: high)
  end

  def second_edition(card_season_id, rarity:)
    card_season = Catalog::CardSeason.find(card_season_id)
    season = Catalog::Season.find_by(number: 2) || Catalog::Season.create!(status: :published, number: 2, published_at: Time.current)
    Catalog::CardSeason.insert_all!([ { card_id: card_season.card_id, season_id: season.id, prestige_score: 0.5, rating: 80.0,
      rarity: Catalog::Rarity::TIERS.invert.fetch(rarity), number: Catalog::CardSeason.where(season_id: season.id).count + 1 } ],
      returning: :id).rows.flatten.sole
  end

  def propose(player, recipient, offer:, request:)
    Game::ProposeTrade.new.call(player:, recipient:, offer:, request:).value!
  end

  def spared_by_lea(*ids) = Game::TradeSuggestions.still_spared(ids, holder: @lea, other: @player)

  def spared_by_player(*ids, other: @lea) = Game::TradeSuggestions.still_spared(ids, holder: @player, other:)

  def count_queries(&block)
    queries = 0
    counter = ->(*, payload) { queries += 1 unless payload[:name].in?([ "SCHEMA", "TRANSACTION" ]) || payload[:cached] }
    ActiveSupport::Notifications.subscribed(counter, "sql.active_record", &block)
    queries
  end

  test "a single copy, or two with one reserved, is spared; a fully reserved copy or a card the holder lacks is not" do
    hold(@lea, @portal, 1)
    hold(@lea, @hills, 2, reserved: 1)
    hold(@lea, @soldier, 1, reserved: 1)

    assert_equal [ @portal, @hills ], spared_by_lea(@portal, @hills, @soldier, @depths)
  end

  test "with a minimum of two copies, a single free copy is not spared but two free copies across editions are" do
    rare_soldier = second_edition(@soldier, rarity: :rare)
    hold(@lea, @portal, 1)
    hold(@lea, @hills, 2, reserved: 1)
    hold(@lea, @depths, 2)
    hold(@lea, @soldier, 1)
    hold(@lea, rare_soldier, 1)

    ids = [ @portal, @hills, @depths, @soldier ]
    assert_equal [ @depths, @soldier ], Game::TradeSuggestions.still_spared(ids, holder: @lea, other: @player, minimum_copies: Game::TradeSuggestions::DUPLICATE_COPIES)
  end

  test "every edition with a free copy is spared" do
    rare_soldier = second_edition(@soldier, rarity: :rare)
    hold(@lea, @soldier, 1)
    hold(@lea, rare_soldier, 1)

    assert_equal [ @soldier, rare_soldier ], spared_by_lea(@soldier, rare_soldier)
  end

  test "a game on the friend's side of an open trade with the player is dropped, whoever proposed it, until it expires" do
    hold(@lea, @portal, 3)
    hold(@lea, @depths, 3)
    hold(@player, @soldier, 1)
    requested = propose(@player, @lea, offer: {}, request: { @portal => 1 })
    offered = propose(@lea, @player, offer: { @depths => 1 }, request: { @soldier => 1 })

    assert_empty spared_by_lea(@portal, @depths)

    Game::Trade.where(id: [ requested.id, offered.id ]).update_all(expires_at: 1.minute.ago)

    assert_equal [ @portal, @depths ], spared_by_lea(@portal, @depths)
  end

  test "the player's own offer to the friend and the friend's request of the player are dropped; a trade with another friend is not" do
    hold(@player, @portal, 4)
    hold(@player, @hills, 4)
    hold(@player, @soldier, 4)
    hold(@lea, @depths, 2)
    hold(@max, @depths, 2)
    propose(@player, @lea, offer: { @portal => 1 }, request: { @depths => 1 })
    propose(@lea, @player, offer: {}, request: { @hills => 1 })
    propose(@player, @max, offer: { @soldier => 1 }, request: { @depths => 1 })

    assert_equal [ @soldier ], spared_by_player(@portal, @hills, @soldier)
    assert_equal [ @portal, @hills ], spared_by_player(@portal, @hills, @soldier, other: @max)
  end

  test "the given order is kept and unknown ids are dropped" do
    [ @hills, @portal, @depths ].each { hold(@lea, it, 2) }
    unknown = Catalog::CardSeason.maximum(:id) + 1

    assert_equal [ @hills, @portal, @depths ], spared_by_lea(@hills, unknown, @portal, @depths)
  end

  test "an empty list reads nothing" do
    assert_equal 0, count_queries { assert_empty spared_by_lea }
  end
end

require "test_helper"
require_relative "../../../support/holdings"
require_relative "../../../support/market"
require_relative "../../../support/market_auctions"
require_relative "../../../support/market_orders"

class Game::Market::WantedCopiesTest < ActiveSupport::TestCase
  include Holdings
  include MarketAuctions
  include MarketOrders
  include MarketSettings

  setup do
    open_market!
    @viewer = accounts_players(:player)
    @goal_seeker = accounts_players(:moderator)
    @buyer = accounts_players(:administrator)
    @rare = catalog_card_seasons(:rare_card_one)
    @common = catalog_card_seasons(:common_card_one)
  end

  def want_by_goal(player, card_season) = Game::Market::Wanted.insert_all([ { player_id: player.id, card_id: card_season.card_id, reason: "goal", rarities: nil } ])

  def place(player, card_season, price)
    fund!(player, price)
    order = order!(player, card_season, price)
    Game::Market::RebuildWanted.new.call(player:).value!
    order
  end

  def ref(card_season) = "#{card_season.card.slug}:#{card_season.season.number}"

  def copies(player = @viewer, **) = Game::Market::WantedCopies.call(player, **)

  test "a goal missing the card and an order reaching its rarity are two seekers, the order the best one" do
    hold(@viewer, @rare.id)
    want_by_goal(@goal_seeker, @rare)
    order = place(@buyer, @rare, 100)

    copy = copies.sole

    assert_equal [ ref(@rare), :rare, 2, order ], [ copy.ref, copy.rarity, copy.seekers, copy.order ]
  end

  test "a player wanting the card both by a goal and an order counts once" do
    hold(@viewer, @rare.id)
    place(@buyer, @rare, 100)
    want_by_goal(@buyer, @rare)

    assert_equal 1, copies.sole.seekers
  end

  test "the viewer's own goals and orders never count" do
    hold(@viewer, @rare.id)
    place(@viewer, @rare, 100)
    want_by_goal(@goal_seeker, @rare)

    copy = copies.sole

    assert_equal 1, copy.seekers
    assert_nil copy.order
  end

  test "a copy only the viewer wants is left out" do
    hold(@viewer, @rare.id)
    want_by_goal(@viewer, @rare)

    assert_empty copies
  end

  test "an order not reaching the copy's rarity neither counts nor serves it" do
    hold(@viewer, @rare.id)
    want_by_goal(@goal_seeker, @rare)
    place(@buyer, @rare, 20)

    copy = copies.sole

    assert_equal 1, copy.seekers
    assert_nil copy.order
  end

  test "an only copy counts, a fully reserved one does not" do
    hold(@viewer, @rare.id, 1)
    hold(@viewer, @common.id, 1, reserved: 1)
    want_by_goal(@goal_seeker, @rare)
    want_by_goal(@goal_seeker, @common)

    assert_equal [ ref(@rare) ], copies.map(&:ref)
  end

  test "a banned player's goal does not count" do
    hold(@viewer, @rare.id)
    want_by_goal(accounts_players(:banned), @rare)

    assert_empty copies
  end

  test "the most sought come first, then the best order, then the ref" do
    uncommon = catalog_card_seasons(:uncommon_card_one)
    portal = catalog_card_seasons(:portal_one)
    [ @rare, @common, uncommon, portal ].each { hold(@viewer, it.id) }
    place(@buyer, @rare, 100)
    place(@goal_seeker, uncommon, 200)
    [ @goal_seeker, @buyer ].each { want_by_goal(it, @common) }
    want_by_goal(@buyer, portal)

    assert_equal [ ref(@common), ref(uncommon), ref(@rare), ref(portal) ], copies.map(&:ref)
  end

  test "card_id keeps one card's editions" do
    hold(@viewer, @rare.id)
    hold(@viewer, @common.id)
    want_by_goal(@goal_seeker, @rare)
    want_by_goal(@goal_seeker, @common)

    assert_equal [ ref(@common) ], copies(card_id: @common.card_id).map(&:ref)
  end

  test "nobody wanting anything and no player both give nothing" do
    hold(@viewer, @rare.id)

    assert_empty copies
    assert_empty Game::Market::WantedCopies.call(nil)
  end

  test "the wanted filter keeps only the editions it is given, and asks for them in its params" do
    hold(@viewer, @rare.id)
    hold(@viewer, @common.id)
    filter = Game::Market::CopyFilter.new(wanted_ids: [ @rare.id ])

    assert_equal [ ref(@rare) ], Game::Market::SellableCopies.call(@viewer, locale: :en, filter:).map(&:ref)
    assert_equal 1, Game::Market::SellableCopies.count(@viewer, locale: :en, filter:)
    assert_equal 0, Game::Market::SellableCopies.count(@viewer, locale: :en, filter: Game::Market::CopyFilter.new(wanted_ids: []))
    assert_equal [ 1, { query: "", rarities: [], wanted: "1" } ], [ filter.count, filter.to_params ]
    assert_not Game::Market::CopyFilter.none.wanted?
  end
end

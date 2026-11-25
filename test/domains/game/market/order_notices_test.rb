require "test_helper"
require_relative "../../../support/game_sets"
require_relative "../../../support/holdings"
require_relative "../../../support/market"
require_relative "../../../support/market_auctions"
require_relative "../../../support/market_orders"

class Game::Market::OrderNoticesTest < ActiveSupport::TestCase
  include GameSets
  include Holdings
  include MarketAuctions
  include MarketOrders
  include MarketSettings

  setup do
    @seller = accounts_players(:player)
    @buyer = accounts_players(:moderator)
    @other_seller = accounts_players(:administrator)
    @settings = open_market!
    @rare = catalog_card_seasons(:rare_card_one)
    @uncommon = catalog_card_seasons(:uncommon_card_one)
    [ @seller, @buyer, @other_seller ].each { fund!(it, 10_000) }
    hold(@seller, @rare.id, 3)
    hold(@other_seller, @rare.id, 1)
    hold(@other_seller, @uncommon.id, 1)
    hold(@seller, @uncommon.id, 1)
  end

  def place!(card_season, price, player: @buyer)
    order = order!(player, card_season, price)
    Game::Market::RebuildWanted.new.call(player:).value!
    order
  end

  def list(card_season = @rare, starting_price:, seller: @seller)
    Game::Market::ListCard.new.call(player: seller, card_season_id: card_season.id, starting_price:, duration_hours: 24, settings_token: @settings.token)
      .value!
  end

  def sell!(order, seller: @seller, card_season: @uncommon)
    Game::Market::SellToOrder.new.call(player: seller, card_season_id: card_season.id, order_token: order.token, settings_token: @settings.token).value!
  end

  def notices(kind) = Game::Market::Notice.where(player_id: @buyer.id, kind:)

  test "a listing above an open order reaching its rarity is noticed against the order, with the seller and the starting price, and no wanted" do
    order = place!(@rare, 100)
    listing = list(starting_price: 150)

    notice = notices("listed_above_order").sole
    assert_equal [ listing.id, order.id, @seller.id, 150 ], [ notice.listing_id, notice.order_id, notice.other_player_id, notice.amount ]
    assert_empty notices("wanted")
  end

  test "a listing at or below the order's price turns the order into a bid, with neither a wanted nor a listed-above notice" do
    order = place!(@rare, 100)
    listing = list(starting_price: 90)

    assert_equal [ [ listing.id, order.id, 100 ] ], notices("order_leads").pluck(:listing_id, :order_id, :amount)
    assert_empty notices("wanted")
    assert_empty notices("listed_above_order")
  end

  test "an order noticed as listed above loses that notice when a later listing converts it" do
    order = place!(@rare, 100)
    list(starting_price: 150)
    assert_equal 1, notices("listed_above_order").count

    listing = list(starting_price: 100)

    assert_empty notices("listed_above_order")
    assert_equal [ [ listing.id, order.id ] ], notices("order_leads").pluck(:listing_id, :order_id)
  end

  test "an order that does not reach the edition's rarity leaves the goal's wanted notice" do
    epic = catalog_card_seasons(:portal_one)
    hold(@seller, epic.id, 1)
    insert_set([ epic.id, *unheld_cards(2) ], { complete: 3 }, key: "roguelike", params: { "theme" => "roguelike" })
    Game::Goal.create!(player_id: @buyer.id, position: 1, set_kind: "theme", set_key: "roguelike")
    place!(epic, 100)

    list(epic, starting_price: 500)

    assert_equal [ 500 ], notices("wanted").pluck(:amount)
    assert_empty notices("listed_above_order")
  end

  test "a second listing above the order replaces the first" do
    place!(@rare, 100)
    list(starting_price: 150)
    second = list(starting_price: 200, seller: @other_seller)

    assert_equal [ [ second.id, @other_seller.id, 200 ] ], notices("listed_above_order").pluck(:listing_id, :other_player_id, :amount)
  end

  test "the listing's end forgets the notice above the order" do
    place!(@rare, 100)
    listing = list(starting_price: 150)

    Game::Market::CancelListing.new.call(player: @seller, listing_id: listing.id).value!

    assert_empty notices("listed_above_order")
  end

  test "a listing's end moves the notice to another listing still above the order" do
    order = place!(@rare, 100)
    first = list(starting_price: 150, seller: @other_seller)
    second = list(starting_price: 200)
    Game::Market::CancelListing.new.call(player: @seller, listing_id: second.id).value!

    assert_equal [ [ first.id, order.id, @other_seller.id, 150 ] ], notices("listed_above_order").pluck(:listing_id, :order_id, :other_player_id, :amount)

    Game::Market::CancelListing.new.call(player: @other_seller, listing_id: first.id).value!

    assert_empty notices("listed_above_order")
  end

  test "a served order forgets its listing above and notices the price paid" do
    order = place!(@uncommon, 100)
    list(@uncommon, starting_price: 150)

    sell!(order, seller: @other_seller)

    assert_empty notices("listed_above_order")
    assert_equal [ [ order.id, 100, nil ] ], notices("order_served").pluck(:order_id, :amount, :listing_id)
  end

  test "an order served from the Confier table notices its buyer and the table's listings notice the others" do
    order = place!(@uncommon, 100)
    list(@uncommon, starting_price: 150)
    lines = [ { card_season_id: @uncommon.id, copies: 1, choice: "order", order_tokens: [ order.token ] } ]

    Game::Market::ApplyWantedChoices.new.call(player: @other_seller, lines:, settings_token: @settings.token).value!

    assert_empty notices("listed_above_order")
    assert_equal [ order.id ], notices("order_served").pluck(:order_id)
  end

  test "the Confier table's listings above an order are noticed against it" do
    order = place!(@rare, 100)
    lines = [ { card_season_id: @rare.id, copies: 1, choice: "auction", starting_price: 150, duration_hours: 24 } ]

    Game::Market::ApplyWantedChoices.new.call(player: @seller, lines:, settings_token: @settings.token).value!

    assert_equal [ [ order.id, @seller.id, 150 ] ], notices("listed_above_order").pluck(:order_id, :other_player_id, :amount)
  end

  test "an expired order forgets its listing above and notices the price released" do
    order = place!(@rare, 100)
    list(starting_price: 150)
    order.update_columns(expires_at: 1.minute.ago)

    Game::Market::ExpireOrder.new.call(player: @buyer, order_id: order.id).value!

    assert_empty notices("listed_above_order")
    assert_equal [ [ order.id, 100 ] ], notices("order_expired").pluck(:order_id, :amount)
  end

  test "a cancelled or withdrawn order forgets its listing above and notices nothing more" do
    cancelled = place!(@rare, 100)
    list(starting_price: 150)
    Game::Market::CancelOrder.new.call(player: @buyer, order_id: cancelled.id).value!

    assert_empty Game::Market::Notice.where(player_id: @buyer.id, order_id: cancelled.id)

    withdrawn = place!(@rare, 100)
    list(starting_price: 150)
    Game::Market::Handlers::OrderNotices.call(Game::Market::OrderWithdrawn.about(withdrawn))

    assert_empty Game::Market::Notice.where(player_id: @buyer.id, order_id: withdrawn.id)
  end

  test "a repriced order's replaced order forgets its listing above" do
    replaced = place!(@rare, 100)
    list(starting_price: 150)

    Game::Market::RepriceOrder.new.call(player: @buyer, order_id: replaced.id, price: 120, settings_token: @settings.token).value!

    assert_empty Game::Market::Notice.where(player_id: @buyer.id, order_id: replaced.id)
  end

  test "a removed owner is not noticed" do
    banned = accounts_players(:banned)
    order = Game::Market::Order.create!(player: banned, card_id: @rare.card_id, settings: @settings, price: 100, expires_at: 1.minute.ago)

    Game::Market::Handlers::OrderNotices.call(Game::Market::OrderExpired.about(order))

    assert_empty Game::Market::Notice.where(player_id: banned.id)
  end

  test "each notice upserts against the index its row needs" do
    indexes = Game::Market::Notice.connection.indexes(:game_market_notices).map { it.name.to_sym }
    chosen = [ [ "outbid", nil ], [ "wanted", nil ], [ "listed_above_order", 1 ], [ "order_served", 1 ], [ "order_expired", 1 ] ]
      .map { |kind, order_id| Game::Market::Notice.unique_index(kind, order_id) }

    assert_equal %i[index_game_market_notices_on_player_and_listing_alone index_game_market_notices_on_player_and_listing_alone
      index_game_market_notices_listed_above_order index_game_market_notices_order_end index_game_market_notices_order_end], chosen
    assert_empty chosen - indexes
  end
end

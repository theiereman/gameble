require "test_helper"
require_relative "../../../support/holdings"
require_relative "../../../support/market"
require_relative "../../../support/market_listings"
require_relative "../../../support/market_auctions"
require_relative "../../../support/market_bidding"

class Game::Market::SaleFeedTest < ActiveSupport::TestCase
  include Holdings
  include MarketAuctions
  include MarketBidding
  include MarketListings
  include MarketSettings

  setup do
    @seller = accounts_players(:player)
    @buyer = accounts_players(:moderator)
    @settings = open_market!(feed_threshold_multiple: 10)
    @common = catalog_card_seasons(:common_card_one)
  end

  def record(card, price, listing_id: 1, buyer: @buyer)
    Game::FeedEntry.record_sale(listing_id:, buyer_id: buyer.id, card_season_id: card.id, price:, settings: @settings, at: Time.current)
  end

  def sales = Game::FeedEntry.where(kind: "sale")

  def sell!(card, price)
    hold(@seller, card.id, 1, reserved: 1)
    @listing = listing!(seller: @seller, card_season: card, starting_price: 1_300, buy_now_price: price, ends_at: 1.day.from_now)
    fund!(@buyer, price)
    assert bid(@buyer, price).success?
  end

  test "a sale of a common at the threshold times its minimum is an entry naming the buyer, the card and the rarity" do
    record(@common, 13_000)

    entry = sales.sole
    assert_equal [ @buyer.id, @common.id, 1, true, 1 ], [ entry.player_id, entry.card_season_id, entry.rarity, entry.notable, entry.listing_id ]
  end

  test "a sale just below the threshold is not an entry" do
    record(@common, 12_999)

    assert_empty sales
  end

  test "an epic or legendary sale is an entry at any price" do
    record(catalog_card_seasons(:legendary_card_one), 1)

    assert_equal [ 5 ], sales.pluck(:rarity)
  end

  test "the threshold is read from the settings version given" do
    @settings = open_market!(feed_threshold_multiple: 2)

    record(@common, 2_600)

    assert_equal 1, sales.count
  end

  test "a listing has one entry whatever happens twice" do
    2.times { record(@common, 20_000) }

    assert_equal 1, sales.count
  end

  test "the database refuses a sale with no listing and an unknown kind" do
    now = Time.current
    row = { player_id: @buyer.id, card_season_id: @common.id, rarity: 1, notable: true, occurred_at: now, created_at: now, updated_at: now }

    [ row.merge(kind: "sale"), row.merge(kind: "auction", listing_id: 1) ].each do |refused|
      assert_raises(ActiveRecord::StatementInvalid) { Game::FeedEntry.transaction(requires_new: true) { Game::FeedEntry.insert_all!([ refused ]) } }
    end
  end

  test "the sale of a listing settled by a buy-now writes its entry in the sale's transaction" do
    sell!(@common, 30_000)

    entry = sales.sole
    assert_equal [ @listing.id, @buyer.id ], [ entry.listing_id, entry.player_id ]
  end

  test "a cheap sale settled by a buy-now writes no entry" do
    sell!(@common, 3_000)

    assert_empty sales
  end

  test "a sale entry is listed whatever the buyer's visibility, unless the buyer is banned or deleted" do
    record(@common, 20_000)
    @buyer.update!(visibility: "private")
    viewer = accounts_players(:administrator)

    assert_equal [ @buyer.id ], Game::FeedEntries.call(viewer).map { it.player.id }
    assert_equal [ @buyer.id ], Game::FeedEntries.call(nil).map { it.player.id }

    @buyer.update_columns(banned_at: Time.current)
    assert_empty Game::FeedEntries.call(viewer)
    @buyer.update_columns(banned_at: nil, deleted_at: Time.current)
    assert_empty Game::FeedEntries.call(viewer)
  end

  test "the new entries of a listing and the entry by token follow the same rule" do
    record(@common, 20_000, listing_id: 7)
    @buyer.update!(visibility: "private")

    assert_equal [ @buyer.id ], Game::NewFeedEntries.call(listing_ids: [ 7 ]).map { it.player.id }
    assert_equal sales.sole, Game::VisibleFeedEntry.call(nil, sales.sole.token)

    @buyer.update_columns(banned_at: Time.current)
    assert_empty Game::NewFeedEntries.call(listing_ids: [ 7 ])
    assert_nil Game::VisibleFeedEntry.call(nil, sales.sole.token)
  end
end

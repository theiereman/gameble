require "test_helper"
require_relative "../support/holdings"
require_relative "../support/market"
require_relative "../support/market_listings"
require_relative "../support/market_auctions"
require_relative "../support/market_orders"
require_relative "../support/singleton_stub"

class MarketPushNoticeJobTest < ActiveJob::TestCase
  include Holdings
  include MarketListings
  include MarketAuctions
  include MarketOrders
  include MarketSettings
  include SingletonStub

  setup do
    @seller = accounts_players(:player)
    @outbid = accounts_players(:moderator)
    @bidder = accounts_players(:administrator)
    @bidder.update!(persona_name: "Max")
    card = catalog_card_seasons(:common_card_one)
    open_market!
    hold(@seller, card.id, 1, reserved: 1)
    @listing = listing!(seller: @seller, card_season: card, starting_price: 20_000, ends_at: 1.day.from_now)
    @phone = Accounts::RegisterPushDevice.new.call(player: @outbid, platform: "apple", token: "outbid-phone", locale: "en").value!
  end

  def pushes = enqueued_jobs.select { it[:job] == ApplicationPushNotificationJob }

  def perform_configured(notices)
    stub_singleton(PushNotices, :deliverable?, ->(_device) { true }) { MarketPushNoticeJob.perform_now(notices) }
  end

  def notice = [ { player_id: @outbid.id, listing_id: @listing.id } ]

  test "an outbid player's devices hear who went past their maximum" do
    Game::Market::Notice.record(player_id: @outbid.id, listing_id: @listing.id, kind: "outbid", other_player_id: @bidder.id, amount: 30_000)
    perform_configured(notice)

    _class_name, attributes, device = pushes.sole[:args]
    assert_match(/\AMax went past your maximum on .+\.\z/, attributes["body"])
    assert_equal "You were outbid", attributes["title"]
    assert_equal @phone.to_global_id.to_s, device["_aj_globalid"]
  end

  test "an owner's devices hear of the order served, never of a listing above it" do
    order = Game::Market::Order.create!(player: @outbid, card_id: catalog_card_seasons(:common_card_one).card_id, settings: Game::Market::CurrentSettings.call,
      price: 100, expires_at: 7.days.from_now)
    Game::Market::Notice.record(player_id: @outbid.id, listing_id: @listing.id, order_id: order.id, kind: "listed_above_order", amount: 20_000)
    perform_configured([ { player_id: @outbid.id, order_id: order.id } ])
    assert_empty pushes

    Game::Market::Notice.record(player_id: @outbid.id, order_id: order.id, kind: "order_expired", amount: 100)
    perform_configured([ { player_id: @outbid.id, order_id: order.id } ])

    _class_name, attributes, _device = pushes.sole[:args]
    assert_equal "Order expired", attributes["title"]
  end

  test "a player without a device, an unconfigured platform or only a wanted line receive nothing" do
    Game::Market::Notice.record(player_id: @outbid.id, listing_id: @listing.id, kind: "wanted", amount: 20_000)
    perform_configured(notice)
    perform_configured([ { player_id: @bidder.id, listing_id: @listing.id } ])
    MarketPushNoticeJob.perform_now(notice)

    assert_empty pushes
  end

  test "a listing over orders pushes the leading owner and the beaten one, each to their own devices" do
    uncommon = catalog_card_seasons(:uncommon_card_one)
    settings = Game::Market::CurrentSettings.call
    hold(@seller, uncommon.id, 1)
    [ @seller, @outbid, @bidder ].each { fund!(it, 1_000) }
    order!(@outbid, uncommon, 400)
    order!(@bidder, uncommon, 350)
    Accounts::RegisterPushDevice.new.call(player: @bidder, platform: "apple", token: "bidder-phone", locale: "en").value!

    assert Game::Market::ListCard.new.call(player: @seller, card_season_id: uncommon.id, starting_price: 300, duration_hours: 24, settings_token: settings.token).success?

    jobs = enqueued_jobs.select { it[:job] == MarketPushNoticeJob }
    assert_equal 1, jobs.size
    perform_configured(jobs.sole[:args].first.map(&:symbolize_keys))

    assert_equal [ "Order leading", "Order outbid" ].sort, pushes.map { it[:args][1]["title"] }.sort
  end
end

require "test_helper"
require_relative "../../support/market"
require_relative "../../support/market_auctions"
require_relative "../../support/market_listings"
require_relative "../../support/market_orders"

class Game::ReleasePlayerMarketTest < ActiveSupport::TestCase
  include ActiveJob::TestHelper
  include MarketAuctions
  include MarketListings
  include MarketOrders
  include MarketSettings

  setup do
    @player = accounts_players(:player)
    @other = accounts_players(:moderator)
    open_market!
    @listing = listing!(seller: @other, card_season: catalog_card_seasons(:common_card_one))
  end

  test "the deletion erases the player's market notices and keeps the notices of others that name them" do
    Game::Market::Notice.record(player_id: @player.id, listing_id: @listing.id, kind: "outbid", other_player_id: @other.id, amount: 5)
    Game::Market::Notice.record(player_id: @other.id, listing_id: @listing.id, kind: "outbid", other_player_id: @player.id, amount: 5)

    assert Game::ReleasePlayer.new.call(player: @player).success?

    assert_equal [ @other.id ], Game::Market::Notice.pluck(:player_id)
  end

  test "the sale entries naming the buyer go with the feed entries" do
    Game::FeedEntry.record_sale(listing_id: @listing.id, buyer_id: @player.id, card_season_id: catalog_card_seasons(:rare_card_one).id, price: 10_000_000,
      settings: Game::Market::CurrentSettings.call, at: Time.current)
    assert_equal 1, Game::FeedEntry.where(player_id: @player.id, kind: "sale").count

    assert Game::ReleasePlayer.new.call(player: @player).success?

    assert_equal 0, Game::FeedEntry.where(kind: "sale", listing_id: @listing.id).count
  end

  test "the wallet and the ledger stay so the balance can still be forfeited" do
    Game::Market::Ledger.post(Game::Market::Mint.credit(player_id: @player.id, amount: 1_000, settings_id: Game::Market::CurrentSettings.call.id))

    assert Game::ReleasePlayer.new.call(player: @player).success?

    assert_equal 1_000, Game::Market::Wallet.find_by!(player_id: @player.id).available
  end

  test "after the deletion and the presence job, no wanted, tied-account or slot row names the player; orders, withdrawals and entries keep them" do
    card = catalog_card_seasons(:rare_card_one)
    settings = Game::Market::CurrentSettings.call
    fund!(@player, 5_000)
    order = order!(@player, card, 900)
    Game::Market::ArchiveWithdrawal.create!(player_id: @player.id, card_season_id: card.id, settings_id: settings.id, purchase_token: SecureRandom.base58(24), price: 100)
    Game::CapacitySlot.create!(player_id: @player.id, kind: "goal", bought: 1)
    low, high = [ @player, @other ].sort_by(&:id)
    Game::Market::TiedAccount.create!(low_account: low, high_account: high, signal: "one_way_trades", facts: {}, refreshed_at: Time.current)

    assert Accounts::DeletePlayer.new.call(player: @player).success?
    perform_enqueued_jobs(only: Game::Market::RefreshWantedJob)
    Game::Market::DropPresenceJob.perform_now

    assert_equal "withdrawn", order.reload.status
    assert_equal [ 0, 0 ], Game::Market::Wallet.find_by!(player_id: @player.id).attributes.values_at("available", "committed")
    assert_empty Game::Market::Wanted.where(player_id: @player.id)
    assert_empty Game::Market::TiedAccount.where(low_account_id: @player.id).or(Game::Market::TiedAccount.where(high_account_id: @player.id))
    assert_empty Game::CapacitySlot.where(player_id: @player.id)
    assert_equal [ @player.id ], Game::Market::Order.where(id: order.id).pluck(:player_id)
    assert_equal 1, Game::Market::ArchiveWithdrawal.where(player_id: @player.id).count
    assert_equal %w[forfeit hold mint release], Game::Market::LedgerEntry.where(player_id: @player.id).distinct.order(:kind).pluck(:kind)
  end
end

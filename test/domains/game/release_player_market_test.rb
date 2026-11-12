require "test_helper"
require_relative "../../support/market"
require_relative "../../support/market_listings"

class Game::ReleasePlayerMarketTest < ActiveSupport::TestCase
  include MarketListings
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
    Game::Market::Mint.credit(player_id: @player.id, amount: 1_000, settings_id: Game::Market::CurrentSettings.call.id)

    assert Game::ReleasePlayer.new.call(player: @player).success?

    assert_equal 1_000, Game::Market::Wallet.find_by!(player_id: @player.id).available
  end
end

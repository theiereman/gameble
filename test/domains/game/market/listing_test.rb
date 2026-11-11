require "test_helper"
require_relative "../../../support/market"
require_relative "../../../support/market_listings"

class Game::Market::ListingTest < ActiveSupport::TestCase
  include MarketSettings
  include MarketListings

  setup do
    @player = accounts_players(:player)
    @settings = open_market!
    @listing = listing!(seller: @player, card_season: catalog_card_seasons(:common_card_one))
  end

  def entry(kind, player: @player, listing: @listing)
    Game::Market::LedgerEntry.insert_all!([ { player_id: player.id, kind:, listing_id: listing&.id, settings_id: @settings.id, created_at: Time.current } ])
  end

  test "a second sale of one listing for one player is refused by the database" do
    entry("sale")
    assert_raises(ActiveRecord::RecordNotUnique) { ActiveRecord::Base.transaction(requires_new: true) { entry("sale") } }
  end

  test "a second stamp, purchase or commission of one listing for one player is refused too" do
    %w[stamp purchase commission].each do |kind|
      entry(kind)
      assert_raises(ActiveRecord::RecordNotUnique) { ActiveRecord::Base.transaction(requires_new: true) { entry(kind) } }
    end
  end

  test "another listing, another player, a second mint and a hold pass" do
    other = listing!(seller: @player, card_season: catalog_card_seasons(:rare_card_one))
    entry("stamp")
    assert_nothing_raised do
      entry("stamp", listing: other)
      entry("stamp", player: accounts_players(:moderator))
      2.times { entry("mint", listing: nil) }
      2.times { entry("hold") }
    end
  end

  test "the table refuses a buy-now not above the start and an unknown status" do
    assert_raises(ActiveRecord::StatementInvalid) { ActiveRecord::Base.transaction(requires_new: true) { @listing.update_columns(buy_now_price: @listing.starting_price) } }
    assert_raises(ActiveRecord::StatementInvalid) { ActiveRecord::Base.transaction(requires_new: true) { @listing.update_columns(status: "lost") } }
    assert_raises(ActiveRecord::StatementInvalid) { ActiveRecord::Base.transaction(requires_new: true) { @listing.update_columns(leader_id: @player.id) } }
  end

  test "a ledger entry can only point at an existing listing" do
    assert_raises(ActiveRecord::InvalidForeignKey) { ActiveRecord::Base.transaction(requires_new: true) { Game::Market::LedgerEntry.insert_all!([ { player_id: @player.id, kind: "stamp", listing_id: 0, settings_id: @settings.id, created_at: Time.current } ]) } }
  end
end

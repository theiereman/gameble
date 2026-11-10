require "test_helper"
require_relative "../../../support/holdings"
require_relative "../../../support/market"
require_relative "../../../support/market_listings"

class Game::Market::RemovalNoticesTest < ActiveSupport::TestCase
  include MarketListings
  include MarketSettings

  setup do
    @seller = accounts_players(:player)
    @leader = accounts_players(:moderator)
    open_market!
    @listing = listing!(seller: @seller, card_season: catalog_card_seasons(:common_card_one))
  end

  def voided = Game::Market::LeadVoided.new(data: { listing_id: @listing.id, seller_id: @seller.id, leader_id: @leader.id, released: 30_000 })

  test "a voided lead tells the seller alone, with no amount and no other player" do
    Game::Market::Handlers::RemovalNotices.call(voided)

    notice = Game::Market::Notice.sole
    assert_equal [ @seller.id, "lead_voided", nil, nil ], notice.attributes.values_at("player_id", "kind", "amount", "other_player_id")
  end

  test "a notice for a banned or deleted player is never written" do
    %i[banned_at deleted_at].each do |column|
      @seller.update_columns(banned_at: nil, deleted_at: nil, column => Time.current)

      Game::Market::Handlers::RemovalNotices.call(voided)
    end

    assert_equal 0, Game::Market::Notice.count
  end
end

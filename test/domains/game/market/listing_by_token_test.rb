require "test_helper"
require_relative "../../../support/market"
require_relative "../../../support/market_listings"

class Game::Market::ListingByTokenTest < ActiveSupport::TestCase
  include MarketSettings
  include MarketListings

  setup do
    @player = accounts_players(:player)
    open_market!
    @listing = listing!(seller: @player, card_season: catalog_card_seasons(:common_card_one))
  end

  test "an unknown token reads nothing" do
    assert_nil Game::Market::ListingByToken.call("nope", locale: :en)
  end

  test "a known token reads the public facts of any status" do
    @listing.update_columns(status: "sold")
    detail = Game::Market::ListingByToken.call(@listing.token, locale: :en)

    assert_equal [ "sold", @player, nil, 1_300, 1_300 ],
      [ detail.status, detail.seller, detail.leader, detail.current_price, detail.starting_price ]
    assert_equal @listing.ends_at.to_i, detail.ends_at.to_i
    assert_equal catalog_card_seasons(:common_card_one).card.slug, detail.card.id
  end

  test "the leader is read and the leader's maximum never" do
    @listing.update_columns(leader_id: accounts_players(:moderator).id, leader_maximum: 9_999, current_price: 1_500)
    detail = Game::Market::ListingByToken.call(@listing.token, locale: :en)

    assert_equal accounts_players(:moderator), detail.leader
    assert_not_includes detail.to_h.keys, :leader_maximum
    assert_no_match(/9999|9_999/, detail.to_h.inspect)
  end
end

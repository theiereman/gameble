require "test_helper"
require_relative "../../../support/market"
require_relative "../../../support/market_listings"

class Game::Market::CardListingsTest < ActiveSupport::TestCase
  include MarketListings
  include MarketSettings

  setup do
    open_market!
    @common = catalog_card_seasons(:common_card_one)
    @seller = accounts_players(:moderator)
  end

  def rare_edition
    season = Catalog::Season.create!(status: :draft, number: Catalog::Season.next_number)
    Catalog::CardSeason.create!(card_id: @common.card_id, season_id: season.id, prestige_score: 0.5, rating: 80.0, rarity: "rare", number: 1)
  end

  test "the open listings of every edition of the card, with their seller, the soonest to end first" do
    later = listing!(seller: @seller, card_season: @common, current_price: 40, hours: 24)
    sooner = listing!(seller: accounts_players(:administrator), card_season: rare_edition, current_price: 300, hours: 2)

    rows = Game::Market::CardListings.call(@common.card_id, locale: :en)

    assert_equal [ sooner.token, later.token ], rows.map(&:token)
    assert_equal [ "rare", "common" ], rows.map { it.card.rarity }
    assert_equal [ accounts_players(:administrator), @seller ], rows.map(&:seller)
    assert_equal [ 300, 40 ], rows.map(&:current_price)
    assert_equal [ 0, 0 ], rows.map(&:offers)
  end

  test "another card's listings and ended ones are absent" do
    listing!(seller: @seller, card_season: catalog_card_seasons(:rare_card_one))
    listing!(seller: @seller, card_season: @common, status: "sold")

    assert_empty Game::Market::CardListings.call(@common.card_id, locale: :en)
  end
end

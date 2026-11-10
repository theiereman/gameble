require "test_helper"
require_relative "../../../support/market"
require_relative "../../../support/market_listings"

class Game::Market::OpenListingsTest < ActiveSupport::TestCase
  include MarketSettings
  include MarketListings

  setup do
    @player = accounts_players(:player)
    open_market!
    @common = catalog_card_seasons(:common_card_one)
    @rare = catalog_card_seasons(:rare_card_one)
    @late = listing!(seller: @player, card_season: @common, starting_price: 5_000, hours: 72, created_at: 3.minutes.ago)
    @soon = listing!(seller: @player, card_season: @rare, starting_price: 9_000, hours: 12, created_at: 2.minutes.ago)
    @middle = listing!(seller: @player, card_season: @common, starting_price: 1_300, hours: 24, created_at: 1.minute.ago)
  end

  def tokens(sort, page: 1) = Game::Market::OpenListings.call(sort:, page:, locale: :en).rows.map(&:token)

  test "the default order is ending soonest first" do
    assert_equal [ @soon, @middle, @late ].map(&:token), tokens("ending")
    assert_equal tokens("ending"), tokens("nonsense")
  end

  test "the price sorts and the newest sort" do
    assert_equal [ @middle, @late, @soon ].map(&:token), tokens("price_asc")
    assert_equal [ @soon, @late, @middle ].map(&:token), tokens("price_desc")
    assert_equal [ @middle, @soon, @late ].map(&:token), tokens("newest")
  end

  test "a tie in price breaks by listing id" do
    tied = listing!(seller: @player, card_season: @rare, starting_price: 5_000, hours: 12)
    assert_equal [ @late, tied ].map(&:token), tokens("price_asc").select { [ @late.token, tied.token ].include?(it) }
    assert_equal [ @late, tied ].map(&:token), tokens("price_desc").select { [ @late.token, tied.token ].include?(it) }
  end

  test "only open listings are read" do
    @soon.update_columns(status: "cancelled")
    assert_equal [ @middle, @late ].map(&:token), tokens("ending")
  end

  test "pages hold 24 rows and say whether more follow" do
    24.times { listing!(seller: @player, card_season: @common, hours: 72) }
    first = Game::Market::OpenListings.call(sort: "ending", page: 1, locale: :en)
    second = Game::Market::OpenListings.call(sort: "ending", page: 2, locale: :en)

    assert_equal [ 24, true ], [ first.rows.size, first.more ]
    assert_equal [ 3, false ], [ second.rows.size, second.more ]
    assert_empty first.rows.map(&:token) & second.rows.map(&:token)
  end

  test "a row carries the card, the amounts, the end and the offers, and no database id nor maximum" do
    row = Game::Market::OpenListings.call(sort: "price_asc", page: 1, locale: :en).rows.first

    assert_equal [ @middle.token, "tin-soldier", 1_300, nil, 0 ], [ row.token, row.card.id, row.current_price, row.buy_now_price, row.offers ]
    assert_equal %i[token card current_price buy_now_price ends_at offers], row.to_h.keys
  end

  test "a listing whose card-season has no view is left out" do
    Catalog::CardSeason.where(id: @rare.id).update_all(rarity: nil)
    assert_equal [ @middle, @late ].map(&:token), tokens("ending")
  end
end

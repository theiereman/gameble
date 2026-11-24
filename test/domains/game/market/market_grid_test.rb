require "test_helper"
require_relative "../../../support/market"
require_relative "../../../support/market_listings"
require_relative "../../../support/archive_at_reference"

class Game::Market::MarketGridTest < ActiveSupport::TestCase
  include ArchiveAtReference
  include MarketSettings
  include MarketListings

  setup do
    @player = accounts_players(:player)
    @common = catalog_card_seasons(:common_card_one)
    @epic = catalog_card_seasons(:portal_one)
    @rare = catalog_card_seasons(:rare_card_one)
    @settings = open_market!(archive_price_rare: 260)
    @cheap = listing!(seller: @player, card_season: @common, starting_price: 80, hours: 48, created_at: Time.current)
    @dear = listing!(seller: @player, card_season: @common, starting_price: 300, hours: 12, created_at: 3.days.ago)
    Game::Market::ArchiveStock.create!(card_season_id: @rare.id, quantity: 2)
    Game::Market::ArchiveStock.create!(card_season_id: @epic.id, quantity: 5)
    Game::Market::ArchiveDeposit.create!(player_id: @player.id, card_season_id: @rare.id, quantity: 2, updated_at: 2.days.ago)
  end

  def grid(sort: "price_asc", page: 1, filters: Game::Market::ListingFilters.none, settings: @settings)
    Game::Market::MarketGrid.call(settings:, sort:, page:, locale: :en, filters:)
  end

  def labels(page) = page.rows.map { it.respond_to?(:token) ? it.token : "archives:#{it.card.id}" }

  def offer = "archives:blue-depths"

  test "the price sorts mix listings and offers, a tie putting the listing first" do
    assert_equal [ @cheap.token, offer, @dear.token ], labels(grid(sort: "price_asc"))
    assert_equal [ @dear.token, offer, @cheap.token ], labels(grid(sort: "price_desc"))

    tied = listing!(seller: @player, card_season: @common, starting_price: 100)

    assert_equal [ @cheap.token, tied.token, offer, @dear.token ], labels(grid(sort: "price_asc"))
  end

  test "ending soonest lists the listings by their end, then the offers by price" do
    settings = open_market!(archive_price_common: 60, archive_price_rare: 260)
    Game::Market::ArchiveStock.create!(card_season_id: @common.id, quantity: 1)

    assert_equal [ @dear.token, @cheap.token, "archives:tin-soldier", offer ], labels(grid(sort: "ending", settings:))
    assert_equal labels(grid(sort: "ending", settings:)), labels(grid(sort: "nonsense", settings:))
  end

  test "newest places an offer by the day its copy joined the Archives" do
    assert_equal [ @cheap.token, offer, @dear.token ], labels(grid(sort: "newest"))
  end

  test "an offer row carries its card, its fixed price and its stock" do
    row = grid.rows.second

    assert_kind_of Game::Market::ArchiveOffers::Row, row
    assert_equal [ "blue-depths", 260, 2 ], [ row.card.id, row.price, row.stock ]
  end

  test "pages hold 24 rows and continue the same order" do
    23.times { listing!(seller: @player, card_season: @common, starting_price: 500) }
    first = grid
    second = grid(page: 2)

    assert_equal [ 24, true ], [ first.rows.size, first.more ]
    assert_equal [ 2, false ], [ second.rows.size, second.more ]
    assert_equal [ @cheap.token, offer, @dear.token ], labels(first).first(3)
  end

  test "the filters apply to offers too, price bounds on the fixed price, hiding one's sales to listings only" do
    assert_equal [ offer ], labels(grid(filters: Game::Market::ListingFilters.from({ q: "blue" })))
    assert_equal [ offer ], labels(grid(filters: Game::Market::ListingFilters.from({ rarity: [ "rare" ] })))
    assert_equal [ offer ], labels(grid(filters: Game::Market::ListingFilters.from({ min_price: "250", max_price: "280" })))
    assert_equal [ offer ], labels(grid(filters: Game::Market::ListingFilters.from({ hide_mine: "1" }, viewer: @player)))
    assert_equal [ offer ], labels(grid(filters: Game::Market::ListingFilters.wanted([ @rare.card_id ])))
    assert_equal [ @cheap.token ], labels(grid(filters: Game::Market::ListingFilters.from({ max_price: "90" })))
  end

  test "the offers count follows the filters" do
    assert_equal 1, Game::Market::MarketGrid.offers_count(settings: @settings, locale: :en)
    assert_equal 0, Game::Market::MarketGrid.offers_count(settings: @settings, locale: :en, filters: Game::Market::ListingFilters.from({ q: "tin" }))
    assert_equal 0, Game::Market::MarketGrid.offers_count(settings: nil, locale: :en)
  end

  test "an Epic is not in the Archives' list" do
    assert_not_includes labels(grid), "archives:portal"
  end

  test "with no settings the grid is the listings alone" do
    assert_equal [ @cheap.token, @dear.token ], labels(grid(settings: nil))
  end
end

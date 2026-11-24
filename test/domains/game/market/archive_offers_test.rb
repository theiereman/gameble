require "test_helper"
require_relative "../../../support/market"
require_relative "../../../support/archive_at_reference"

class Game::Market::ArchiveOffersTest < ActiveSupport::TestCase
  include ArchiveAtReference
  include MarketSettings

  setup do
    @common = catalog_card_seasons(:common_card_one)
    @epic = catalog_card_seasons(:portal_one)
    @rare = catalog_card_seasons(:rare_card_one)
    @settings = open_market!(archive_price_common: 50, archive_price_rare: 500)
    { @common => 4, @epic => 2, @rare => 1 }.each { |card, quantity| Game::Market::ArchiveStock.create!(card_season_id: card.id, quantity:) }
  end

  def offers(sort: "price_asc", page: 1, filters: Game::Market::ListingFilters.none, settings: @settings)
    Game::Market::ArchiveOffers.call(settings:, sort:, page:, locale: :en, filters:)
  end

  def titles(page) = page.rows.map { it.card.title }

  test "the list leaves Epics out and offers each edition at its rarity's price with its stock" do
    page = offers

    assert_equal [ [ "Tin Soldier", 50, 4 ], [ "Blue Depths", 500, 1 ] ], page.rows.map { [ it.card.title, it.price, it.stock ] }
    assert_not page.more
    assert_equal %w[common uncommon rare], Game::Market::ArchiveOffers.listed_rarities
  end

  test "prices sort ascending by default and descending on demand" do
    assert_equal [ "Tin Soldier", "Blue Depths" ], titles(offers(sort: "unknown"))
    assert_equal [ "Blue Depths", "Tin Soldier" ], titles(offers(sort: "price_desc"))
  end

  test "filters keep the matching offers and the count follows them" do
    filters = Game::Market::ListingFilters.from({ rarity: [ "rare" ] })

    assert_equal [ "Blue Depths" ], titles(offers(filters:))
    assert_equal [ 1, 1 ], Game::Market::ArchiveOffers.count(settings: @settings, locale: :en, filters:).to_h.values
    assert_equal [ "Tin Soldier" ], titles(offers(filters: Game::Market::ListingFilters.from({ q: "tin" })))
    assert_equal [ "Tin Soldier" ], titles(offers(filters: Game::Market::ListingFilters.wanted([ @common.card_id ])))
  end

  test "the count is of distinct cards and of editions" do
    assert_equal({ cards: 2, editions: 2 }, Game::Market::ArchiveOffers.count(settings: @settings, locale: :en).to_h)
  end

  test "a page says when more offers follow" do
    assert_equal 24, Game::Market::ArchiveOffers::PER_PAGE
    with_per_page(1) do
      first = offers
      second = offers(page: 2)

      assert_equal [ [ "Tin Soldier" ], true ], [ titles(first), first.more ]
      assert_equal [ [ "Blue Depths" ], false ], [ titles(second), second.more ]
    end
  end

  def with_per_page(size)
    original = Game::Market::ArchiveOffers::PER_PAGE
    Game::Market::ArchiveOffers.send(:remove_const, :PER_PAGE)
    Game::Market::ArchiveOffers.const_set(:PER_PAGE, size)
    yield
  ensure
    Game::Market::ArchiveOffers.send(:remove_const, :PER_PAGE)
    Game::Market::ArchiveOffers.const_set(:PER_PAGE, original)
  end

  test "one edition is found while it is offered" do
    assert_equal 500, Game::Market::ArchiveOffers.find(settings: @settings, card_season_id: @rare.id, locale: :en).price
    assert_nil Game::Market::ArchiveOffers.find(settings: @settings, card_season_id: @epic.id, locale: :en)
  end

  test "a rarity with no back-office reference sells at its default reference" do
    settings = open_market!

    assert_equal [ 50, 250 ], offers(settings:).rows.map(&:price), "the defaults sit under five times the entrustment value here"
  end

  test "the featured offers put the wanted card first, then the latest entrusted, then the edition, up to the limit" do
    player = accounts_players(:player)
    Game::Market::ArchiveDeposit.create!(player_id: player.id, card_season_id: @common.id, quantity: 4, updated_at: 3.days.ago)
    Game::Market::ArchiveDeposit.create!(player_id: player.id, card_season_id: @rare.id, quantity: 1, updated_at: 1.day.ago)

    featured = ->(**options) { Game::Market::ArchiveOffers.featured(settings: @settings, locale: :en, **options).map { it.card.title } }

    assert_equal [ "Blue Depths", "Tin Soldier" ], featured.call(wanted_card_ids: [])
    assert_equal [ "Tin Soldier", "Blue Depths" ], featured.call(wanted_card_ids: [ @common.card_id ])
    assert_equal [ "Blue Depths" ], featured.call(wanted_card_ids: [], limit: 1)
  end

  test "the offers of one game list its listed editions by price" do
    offers = Game::Market::ArchiveOffers.for_card(settings: @settings, card_id: @rare.card_id, locale: :en)

    assert_equal [ [ "Blue Depths", 500, 1 ] ], offers.map { [ it.card.title, it.price, it.stock ] }
    assert_empty Game::Market::ArchiveOffers.for_card(settings: @settings, card_id: @epic.card_id, locale: :en)
  end

  test "the list takes the most wanted, then Rares, then Uncommons before Commons, up to its size" do
    uncommon = catalog_card_seasons(:uncommon_card_one)
    Game::Market::ArchiveStock.create!(card_season_id: uncommon.id, quantity: 1)
    Game::Market::Wanted.create!(player_id: accounts_players(:moderator).id, card_id: @common.card_id, reason: "goal")
    list = ->(size) { Game::Market::ArchiveOffers.list(open_market!(archive_list_size: size)) }

    assert_equal [ @common.id, @rare.id ], list.(2)
    assert_equal [ @common.id, @rare.id, uncommon.id ], list.(3)
  end
end

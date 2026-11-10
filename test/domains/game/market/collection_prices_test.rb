require "test_helper"
require_relative "../../../support/holdings"
require_relative "../../../support/market"
require_relative "../../../support/second_season"

class Game::Market::CollectionPricesTest < ActiveSupport::TestCase
  include Holdings
  include MarketSettings
  include SecondSeason

  setup do
    @player = accounts_players(:player)
    @season = catalog_seasons(:one)
    @common = catalog_card_seasons(:common_card_one)
    @uncommon = catalog_card_seasons(:uncommon_card_one)
    @rare = catalog_card_seasons(:rare_card_one)
    @portal = catalog_card_seasons(:portal_one)
    @legendary = catalog_card_seasons(:legendary_card_one)
    open_market!(first_opened_at: 1.day.ago)
    price!(@common, 1_000, 5)
    price!(@uncommon, 4_000, 3)
    price!(@rare, 9_000, 2)
    price!(@portal, 30_000, 5)
  end

  def price!(card, average, sales) = Game::Market::EditionPrice.create!(card_season_id: card.id, average:, sales_used: sales)

  def choice(sort: nil, minimum: nil, maximum: nil) = Game::Market::CollectionPrices.choice(sort:, minimum:, maximum:)

  def cards(player = @player, **asked)
    relation = Game::CollectionTiles.call(player, @season)
    Game::Market::CollectionPrices.apply(relation, choice(**asked), owner: player).pluck(:id)
  end

  def ids(*cards) = cards.map(&:id)

  test "sorting descending puts the dearest first and the cards with no sale last" do
    assert_equal ids(@portal, @rare, @uncommon, @common, @legendary), cards(sort: "price_desc")
  end

  test "sorting ascending keeps the cards with no sale last" do
    assert_equal ids(@common, @uncommon, @rare, @portal, @legendary), cards(sort: "price_asc")
  end

  test "a range keeps the cards inside it, ends included, and never a card with no sale" do
    assert_equal ids(@uncommon, @rare).sort, cards(minimum: "4000", maximum: "9000").sort
    assert_equal ids(@portal), cards(minimum: "30000")
    assert_equal ids(@common).sort, cards(maximum: "1000").sort
  end

  test "a minimum above the maximum matches nothing" do
    assert_empty cards(minimum: "9000", maximum: "4000")
  end

  test "a range and a sort together" do
    assert_equal ids(@rare, @uncommon), cards(sort: "price_desc", minimum: "2000", maximum: "10000")
  end

  test "an owner's most valuable copy is compared, shown with its own state" do
    season, = publish_second_season(@player, held: [])
    dearer = Catalog::CardSeason.find_by!(card_id: @common.card_id, season_id: season.id)
    price!(dearer, 50_000, 1)
    hold(@player, @common.id, 1)
    hold(@player, dearer.id, 1)

    relation = Game::CollectionTiles.call(@player, season)
    sorted = Game::Market::CollectionPrices.apply(relation, choice(sort: "price_desc"), owner: @player)

    assert_equal dearer.card_id, sorted.pick(:card_id)
    price = Game::Market::CollectionPrices.for_cards([ [ dearer.id, dearer.card_id ] ], owner: @player).fetch(dearer.card_id)
    assert_equal 50_000, price.average
    assert price.few_sales?
  end

  test "a card the viewer does not hold is priced by the grid's edition" do
    hold(@player, @rare.id, 1)

    prices = Game::Market::CollectionPrices.for_cards([ [ @common.id, @common.card_id ], [ @rare.id, @rare.card_id ] ], owner: @player)

    assert prices.fetch(@common.card_id).priced?
    assert_equal 9_000, prices.fetch(@rare.card_id).average
  end

  test "a held card with no sale is no sale, not the published season's price" do
    season, = publish_second_season(@player, held: [])
    unsold = Catalog::CardSeason.find_by!(card_id: @common.card_id, season_id: season.id)
    hold(@player, unsold.id, 1)

    price = Game::Market::CollectionPrices.for_cards([ [ unsold.id, unsold.card_id ] ], owner: @player).fetch(unsold.card_id)

    assert price.no_sale?
  end

  test "a visitor has no holdings: the grid's edition prices every card" do
    assert_equal ids(@portal, @rare, @uncommon, @common, @legendary), cards(nil, sort: "price_desc")
  end

  test "nothing is applied before the first opening: the choice is empty" do
    Game::Market::Settings.delete_all
    open_market!

    chosen = choice(sort: "price_desc", minimum: "100")

    assert_not chosen.active?
    relation = Game::CollectionTiles.call(@player, @season)
    assert_same relation, Game::Market::CollectionPrices.apply(relation, chosen, owner: @player)
  end

  test "an invalid value is ignored" do
    chosen = choice(sort: "up", minimum: "abc", maximum: "-4")

    assert_not chosen.active?
    assert_equal 0, chosen.count
  end

  test "the count and the params of a choice" do
    chosen = choice(sort: "price_asc", minimum: "100")

    assert_equal 2, chosen.count
    assert_equal({ sort: "price_asc", min_price: 100 }, chosen.params)
  end
end

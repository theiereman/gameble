require "test_helper"
require_relative "../../../support/holdings"
require_relative "../../../support/market"
require_relative "../../../support/market_auctions"
require_relative "../../../support/market_orders"

class Game::Market::WantedTableTest < ActiveSupport::TestCase
  include Holdings
  include MarketAuctions
  include MarketOrders
  include MarketSettings

  setup do
    @settings = open_market!(first_opened_at: 1.day.ago)
    @seller = accounts_players(:player)
    @seeker = accounts_players(:moderator)
    @buyer = accounts_players(:administrator)
    @rare = catalog_card_seasons(:rare_card_one)
    @common = catalog_card_seasons(:common_card_one)
    @uncommon = catalog_card_seasons(:uncommon_card_one)
  end

  def want_by_goal(player, card_season) = Game::Market::Wanted.insert_all([ { player_id: player.id, card_id: card_season.card_id, reason: "goal", rarities: nil } ])

  def place(player, card_season, price)
    fund!(player, price)
    order = order!(player, card_season, price)
    Game::Market::RebuildWanted.new.call(player:).value!
    order
  end

  def ref(card_season) = "#{card_season.card.slug}:#{card_season.season.number}"

  def table(copies) = Game::Market::WantedTable.call(@seller, copies: copies.transform_keys(&:id), settings: @settings)

  test "a line carries its seekers, its average, its amounts and the orders its copies serve" do
    hold(@seller, @uncommon.id, 3)
    want_by_goal(@seeker, @uncommon)
    best = place(@buyer, @uncommon, 900)
    second = place(@seeker, @uncommon, 800)
    Game::Market::EditionPrice.create!(card_season_id: @uncommon.id, average: 1_000, sales_used: 5)

    line = table(@uncommon => 2).sole

    assert_equal [ @uncommon.id, ref(@uncommon), :uncommon, 2, 2, [ best, second ], 1_000 ],
      [ line.card_season_id, line.ref, line.rarity, line.copies, line.seekers, line.orders, line.price.average ]
    assert_equal [ @settings.entrustment(:uncommon), @settings.minimum_price(:uncommon), @settings.stamp(:uncommon) ], [ line.value, line.minimum, line.stamp ]
  end

  test "a Rare and above line draws no order and reads the prices of the orders that would back its auction, best first" do
    epic = catalog_card_seasons(:portal_one)
    hold(@seller, @rare.id, 2)
    hold(@seller, epic.id)
    place(@buyer, @rare, 900)
    place(@seeker, @rare, 800)

    lines = table(@rare => 2, epic => 1)
    rare_line = lines.find { it.card_season_id == @rare.id }

    assert_equal [ ref(@rare), ref(epic) ], lines.map(&:ref)
    assert_equal [ [ false, [], [ 900, 800 ], 900 ], [ false, [], [], nil ] ],
      [ rare_line, lines.last ].map { [ it.direct?, it.orders, it.backing, it.best_price ] }
  end

  test "lines come best order first, none last, then the most seekers, the highest value and the ref" do
    [ @rare, @common, @uncommon ].each { hold(@seller, it.id) }
    place(@buyer, @common, 300)
    want_by_goal(@seeker, @rare)
    want_by_goal(@seeker, @uncommon)
    want_by_goal(@buyer, @uncommon)

    assert_equal [ ref(@common), ref(@uncommon), ref(@rare) ], table(@rare => 1, @common => 1, @uncommon => 1).map(&:ref)
  end

  test "editions of one card share its orders: each order goes once, to the earlier line" do
    season = Catalog::Season.create!(status: :published, number: 2, published_at: Time.current)
    later = Catalog::CardSeason.find(Catalog::CardSeason.insert_all!([ { card_id: @uncommon.card_id, season_id: season.id, prestige_score: 0.7, rating: 80.0,
      rarity: @uncommon.rarity_before_type_cast, number: @uncommon.number } ], returning: :id).rows.flatten.sole)
    hold(@seller, @uncommon.id)
    hold(@seller, later.id)
    best = place(@buyer, @uncommon, 900)
    second = place(@seeker, @uncommon, 800)

    lines = table(@uncommon => 1, later => 1)

    assert_equal [ [ ref(@uncommon), [ best ] ], [ ref(later), [ second ] ] ], lines.map { [ it.ref, it.orders ] }
  end

  test "the seller's own orders and a removed player's are never drawn" do
    hold(@seller, @uncommon.id)
    place(@seller, @uncommon, 900)
    place(accounts_players(:banned), @uncommon, 950)

    assert_empty table(@uncommon => 1).sole.orders
  end

  test "copies are clamped to those still free, a line with none dropped, and a line nobody wants kept at zero seekers" do
    hold(@seller, @rare.id, 3, reserved: 2)
    hold(@seller, @common.id, 1, reserved: 1)
    hold(@seller, @uncommon.id)

    lines = table(@rare => 3, @common => 1, @uncommon => 1)

    assert_equal [ [ ref(@rare), 1, 0 ], [ ref(@uncommon), 1, 0 ] ], lines.map { [ it.ref, it.copies, it.seekers ] }
  end

  test "nothing asked or nothing held draws nothing" do
    assert_empty table({})
    assert_empty table(@rare => 1)
  end
end

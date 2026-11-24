require "test_helper"
require_relative "../../../support/market"
require_relative "../../../support/market_sales"

class Game::Market::ArchivePricesTest < ActiveSupport::TestCase
  include MarketSales
  include MarketSettings

  setup do
    @common = catalog_card_seasons(:common_card_one)
    @uncommon = catalog_card_seasons(:uncommon_card_one)
    @rare = catalog_card_seasons(:rare_card_one)
    @monday = Time.utc(2026, 11, 23)
    travel_to @monday + 9.hours
    @settings = open_market!(archive_price_rare: 100, archive_price_common: 5)
    @player = accounts_players(:player)
  end

  def prices(now = Time.current) = Game::Market::ArchivePrices.call(@settings, now:)

  def sell!(*amounts) = amounts.each_with_index { |amount, index| sold!(@rare, amount, sold_at: @monday - (index + 1).hours) }

  def ledger!(kind, amount, at) = Game::Market::LedgerEntry.create!(player_id: @player.id, kind:, available_delta: amount, committed_delta: 0,
    settings_id: @settings.id, created_at: at)

  def first_purchase!(at) = Game::Market::ArchiveWithdrawal.create!(player_id: @player.id, card_season_id: @common.id,
    purchase_token: SecureRandom.base58(24), price: 50, settings_id: @settings.id, created_at: at)

  test "under five sales a rarity sells at six times its back-office reference, else its default, never under five times its entrustment value" do
    sell!(5_000, 6_000, 7_000, 8_000)

    assert_equal 600, prices[:rare]
    assert_equal 50, prices[:common], "six times 5 is under five times the entrustment value of 10"
    assert_equal 600, prices[:uncommon], "the default reference of 100"
    assert_equal 600, prices(@monday + 6.days)[:rare], "one price all week"
  end

  test "from five sales the reference is their median, the top and bottom tenth left out, sales of the week not counted" do
    sell!(100, 150, 150, 200, 9_000)
    sold!(@rare, 50_000, sold_at: @monday + 1.hour)

    assert_equal 900, prices[:rare]
    assert_equal 1_050, prices(@monday + 7.days)[:rare], "next Monday counts the sales of this week"
  end

  test "the coefficient stays at six until the Archives first sold a card" do
    ledger!("mint", 1_000, @monday - 2.weeks)

    assert_equal 600, prices[:rare]
  end

  test "each Monday the coefficient moves toward the set point by a fifth at most, between two and ten" do
    first_purchase!(@monday - 2.weeks)
    ledger!("mint", 1_000, @monday - 2.weeks)

    assert_equal 864, prices[:rare], "nothing destroyed: six, up a fifth on each of two Mondays"

    ledger!("archive_purchase", -900, @monday - 2.weeks)
    assert_equal 384, prices[:rare], "90 % destroyed, past the set point: down a fifth on each Monday"
  end

  test "the coefficient never passes ten, and the back-office hears of it" do
    first_purchase!(@monday - 20.weeks)
    ledger!("mint", 1_000, @monday - 20.weeks)
    (1..20).each { ledger!("mint", 1_000, @monday - it.weeks) }

    assert_equal 1_000, prices[:rare]
    assert Game::Market::ArchivePrices.at_ceiling?
  end

  test "an Epic or Legendary auction opens at twice the reference, never under five times the entrustment value" do
    assert_equal 3_300, Game::Market::ArchivePrices.reserve(@settings, :epic)
    assert_equal 8_000, Game::Market::ArchivePrices.reserve(@settings, :legendary)
  end
end

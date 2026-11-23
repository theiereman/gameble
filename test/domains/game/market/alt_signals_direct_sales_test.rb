require "test_helper"
require_relative "../../../support/alt_signal_seeds"
require_relative "../../../support/market"

class Game::Market::AltSignalsDirectSalesTest < ActiveSupport::TestCase
  include AltSignalSeeds
  include MarketSettings

  setup do
    @alice = accounts_players(:player)
    @bob = accounts_players(:moderator)
    @carol = accounts_players(:administrator)
    @card = catalog_card_seasons(:common_card_one)
    open_market!(first_opened_at: 90.days.ago)
    Game::Pack.update_all(opened_at: nil)
    Game::Market::AltSignal.delete_all
    Game::Market::TiedAccount.delete_all
    @now = Time.current
  end

  def detected(signal) = Game::Market::AltSignals.call(now: @now).select { it.signal == signal }

  def edition_facts(card_season) = { "card" => card_season.card.slug, "season" => card_season.season.number }

  def tie_through_minimum_price_sales!
    3.times { |ago| sale!(@alice, @bob, @card, 13, sold_at: (ago + 1).days.ago) }
  end

  def deposit!(player, at:, quantity: 2)
    Game::Market::ArchiveDeposit.create!(player_id: player.id, card_season_id: @card.id, quantity:, created_at: at, updated_at: at)
  end

  def purchase!(player, at: 1.day.ago, price: 500)
    Game::Market::ArchiveWithdrawal.create!(player_id: player.id, card_season_id: @card.id, settings_id: Game::Market::CurrentSettings.call.id,
      purchase_token: SecureRandom.base58(24), price:, created_at: at)
  end

  test "served orders under half and over twice the average count as sales outside the market price" do
    priced_history!(@card, average: 100)
    served!(@card, 49, served_at: 2.days.ago, seller: @alice, buyer: @bob, average_after_sale: 100)
    served!(@card, 201, served_at: 1.day.ago, seller: @alice, buyer: @bob, average_after_sale: 100)

    found = detected("sales_outside_price")

    assert_equal [ [ @alice.id, @bob.id, { "sales" => 2, "below" => 1, "above" => 1 } ] ], found.map { [ it.account_id, it.other_account_id, it.facts ] }
  end

  test "a served order and a sold listing of one pair add up outside the market price" do
    priced_history!(@card, average: 100)
    sale!(@alice, @bob, @card, 49, sold_at: 2.days.ago, average_after_sale: 100)
    served!(@card, 201, served_at: 1.day.ago, seller: @alice, buyer: @bob, average_after_sale: 100)

    assert_equal [ { "sales" => 2, "below" => 1, "above" => 1 } ], detected("sales_outside_price").map(&:facts)
  end

  test "direct sales at the minimum tie two accounts, and each sale to the tied buyer's order is a signal with the order's facts" do
    3.times { |ago| served!(@card, 13, served_at: (ago + 1).days.ago, seller: @alice, buyer: @bob) }
    served!(@card, 40, served_at: 1.day.ago, seller: @alice, buyer: @carol)

    Game::Market::RefreshAltSignals.new.call(now: @now).value!

    assert_equal [ [ @alice, @bob ].minmax_by(&:id).map(&:id) ], Game::Market::TiedAccount.where(signal: "minimum_price_sales").pluck(:low_account_id, :high_account_id)
    rows = Game::Market::AltSignal.where(signal: "order_sale_to_tied_buyer").to_a
    assert_equal [ [ @alice.id, @bob.id ] ] * 3, rows.map { [ it.account_id, it.other_account_id ] }
    assert_equal [ edition_facts(@card).merge("price" => 13) ], rows.map(&:facts).uniq
  end

  test "a direct sale is a minimum-price sale against the serving copy's rarity minimum in the order's version" do
    3.times { |ago| served!(catalog_card_seasons(:uncommon_card_one), 13, served_at: (ago + 1).days.ago, seller: @alice, buyer: @bob) }

    assert_empty detected("minimum_price_sales")
  end

  test "a direct sale to an untied account's order, or older than 30 days, is not a signal" do
    tie_through_minimum_price_sales!
    served!(@card, 40, served_at: 1.day.ago, seller: @alice, buyer: @carol)
    served!(@card, 40, served_at: 31.days.ago, seller: @alice, buyer: @bob)

    assert_empty detected("order_sale_to_tied_buyer")
  end

  test "buying from the Archives an edition a tied account entrusted in the window is a signal naming the depositor and the deposit" do
    tie_through_minimum_price_sales!
    deposit!(@bob, at: 3.days.ago, quantity: 2)
    deposited_at = Game::Market::ArchiveDeposit.sole.updated_at
    purchase!(@alice, price: 500)

    found = detected("archive_purchase_of_tied_deposit")

    assert_equal [ [ @alice.id, @bob.id ] ], found.map { [ it.account_id, it.other_account_id ] }
    assert_equal edition_facts(@card).merge("price" => 500, "deposited" => 2, "deposited_on" => deposited_at.utc.to_date.iso8601), found.sole.facts
  end

  test "an Archive purchase outside the window, of a deposit outside it, of an untied depositor or of the buyer's own deposit is not a signal" do
    tie_through_minimum_price_sales!
    deposit!(@bob, at: 31.days.ago)
    deposit!(@carol, at: 3.days.ago)
    deposit!(@alice, at: 3.days.ago)
    purchase!(@alice)
    purchase!(@bob, at: 31.days.ago)

    assert_empty detected("archive_purchase_of_tied_deposit")
  end

  test "an Archive purchase with no tie is not a signal" do
    deposit!(@bob, at: 3.days.ago)
    purchase!(@alice)

    assert_empty detected("archive_purchase_of_tied_deposit")
  end
end

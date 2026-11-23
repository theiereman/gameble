require "test_helper"
require_relative "../../../support/holdings"
require_relative "../../../support/market"

class Game::Market::SumArchiveStocksTest < ActiveSupport::TestCase
  include Holdings
  include MarketSettings

  setup do
    @alice = accounts_players(:player)
    @bob = accounts_players(:moderator)
    @common = catalog_card_seasons(:common_card_one)
    @rare = catalog_card_seasons(:rare_card_one)
    @settings = open_market!
  end

  def entrust(player, card_season, copies)
    hold(player, card_season.id, copies)
    Game::Market::EntrustCards.new.call(player:, lines: { card_season.id => copies }, settings_token: @settings.token).value!
  end

  def sum(now: Time.current) = Game::Market::SumArchiveStocks.new.call(now:)

  def stocks = Game::Market::ArchiveStock.pluck(:card_season_id, :quantity).to_h

  test "the deposits of two players for one card-season sum into one stock row" do
    entrust(@alice, @common, 3)
    entrust(@bob, @common, 4)

    assert_equal 1, sum.value!
    assert_equal({ @common.id => 7 }, stocks)
  end

  test "a second run changes nothing and keeps updated_at" do
    entrust(@alice, @common, 3)
    sum(now: 2.hours.ago)
    before = Game::Market::ArchiveStock.pluck(:id, :quantity, :updated_at)

    assert_equal 0, sum.value!
    assert_equal before, Game::Market::ArchiveStock.pluck(:id, :quantity, :updated_at)
  end

  test "a later entrustment moves only the stock of its card" do
    entrust(@alice, @common, 3)
    entrust(@alice, @rare, 2)
    sum(now: 2.hours.ago)
    untouched = Game::Market::ArchiveStock.find_by!(card_season_id: @rare.id).updated_at

    entrust(@bob, @common, 1)

    assert_equal 1, sum.value!
    assert_equal({ @common.id => 4, @rare.id => 2 }, stocks)
    assert_equal untouched, Game::Market::ArchiveStock.find_by!(card_season_id: @rare.id).updated_at
  end

  test "a deleted player's deposits keep counting" do
    entrust(@alice, @common, 5)
    Accounts::DeletePlayer.new.call(player: @alice).value!

    sum.value!

    assert_equal({ @common.id => 5 }, stocks)
    assert_equal 1, Game::Market::ArchiveDeposit.where(player_id: @alice.id).count
  end

  test "a stock without deposits is deleted" do
    Game::Market::ArchiveStock.create!(card_season_id: @common.id, quantity: 2)

    assert_equal 1, sum.value!
    assert_empty stocks
  end

  test "no deposit gives no stock" do
    assert_equal 0, sum.value!
    assert_empty stocks
  end

  test "entrusting alone writes no stock row" do
    assert_no_difference -> { Game::Market::ArchiveStock.count } do
      entrust(@alice, @common, 2)
    end
  end

  def withdraw(card_season, count, player: @bob)
    count.times do
      Game::Market::ArchiveWithdrawal.create!(player_id: player.id, card_season_id: card_season.id, purchase_token: SecureRandom.base58(24),
        price: 500, settings_id: @settings.id, created_at: Time.current)
    end
  end

  test "a stock is the deposits less the withdrawals" do
    entrust(@alice, @common, 3)
    withdraw(@common, 1)

    sum

    assert_equal({ @common.id => 2 }, stocks)
  end

  test "a stock whose withdrawals reach or pass its deposits is deleted, never set to zero, which its check refuses" do
    entrust(@alice, @common, 3)
    sum
    withdraw(@common, 3)

    assert_equal 1, sum.value!
    assert_empty stocks

    Game::Market::ArchiveStock.create!(card_season_id: @common.id, quantity: 1)
    withdraw(@common, 1)

    assert_equal 1, sum.value!
    assert_empty stocks
  end

  test "a stock row without a deposit is deleted even with a withdrawal" do
    Game::Market::ArchiveStock.create!(card_season_id: @common.id, quantity: 2)
    withdraw(@common, 1)

    assert_equal 1, sum.value!
    assert_empty stocks
  end

  test "a sum after a purchase equals the row the purchase lowered" do
    @settings = open_market!(archive_price_rare: 500)
    entrust(@alice, @rare, 3)
    sum(now: 2.hours.ago)
    Game::Market::Ledger.post(Game::Market::Mint.credit(player_id: @bob.id, amount: 1_000, settings_id: Game::Market::CurrentSettings.call.id))
    Game::Market::BuyFromArchives.new.call(player: @bob, card_season_id: @rare.id, purchase_token: SecureRandom.base58(24),
      settings_token: Game::Market::CurrentSettings.call.token).value!
    lowered = Game::Market::ArchiveStock.pluck(:id, :quantity, :updated_at)

    assert_equal 0, sum.value!
    assert_equal({ @rare.id => 2 }, stocks)
    assert_equal lowered, Game::Market::ArchiveStock.pluck(:id, :quantity, :updated_at)
  end
end

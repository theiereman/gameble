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
end

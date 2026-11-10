require "test_helper"
require_relative "../../../support/holdings"
require_relative "../../../support/market"

class Game::Market::CardEntrustmentTest < ActiveSupport::TestCase
  include Holdings
  include MarketSettings

  setup do
    Game::Market::Settings.delete_all
    @player = accounts_players(:player)
    @rare = catalog_card_seasons(:rare_card_one)
  end

  def call(player = @player) = Game::Market::CardEntrustment.call(player, card_id: @rare.card_id)

  test "a market that never opened gives nothing" do
    hold(@player, @rare.id, 2)

    assert_nil call
  end

  test "a market closed after its opening gives nothing" do
    open_market!
    close_market!
    hold(@player, @rare.id, 2)

    assert_nil call
  end

  test "a visitor gets nothing" do
    open_market!

    assert_nil call(nil)
  end

  test "a card the player does not hold gives nothing" do
    open_market!
    hold(@player, catalog_card_seasons(:common_card_one).id, 2)
    hold(@player, @rare.id, 0)

    assert_nil call
  end

  test "an edition without a rarity is not counted" do
    open_market!
    hold(@player, @rare.id, 2)
    @rare.update_columns(rarity: nil)

    assert_nil call
  end

  test "free copies are counted with the reserved ones" do
    open_market!
    hold(@player, @rare.id, 3, reserved: 1)

    assert_equal Game::Market::CardEntrustment::State.new(free: 2, reserved: 1), call
  end

  test "every copy reserved leaves none free" do
    open_market!
    hold(@player, @rare.id, 2, reserved: 2)

    assert_equal Game::Market::CardEntrustment::State.new(free: 0, reserved: 2), call
  end

  test "the sums run over the editions of the card" do
    open_market!
    other = Catalog::Season.create!(status: :published, number: 2, published_at: Time.current)
    second = Catalog::CardSeason.create!(card_id: @rare.card_id, season_id: other.id, prestige_score: 0.5, rating: 50, rarity: @rare.rarity, number: 1)
    hold(@player, @rare.id, 2, reserved: 2)
    hold(@player, second.id, 3, reserved: 1)

    assert_equal Game::Market::CardEntrustment::State.new(free: 2, reserved: 3), call
  end
end

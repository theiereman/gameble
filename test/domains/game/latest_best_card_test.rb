require "test_helper"
require_relative "../../support/catalog_seeds"
require_relative "../../support/game_packs"
require_relative "../../support/game_trades"
require_relative "../../support/holdings"

class Game::LatestBestCardTest < ActiveSupport::TestCase
  include Holdings
  include CatalogSeeds
  include GamePacks
  include GameTrades

  setup do
    @player = accounts_players(:player)
    @partner = accounts_players(:moderator)
    @season = catalog_seasons(:one)
    @common, @uncommon, @rare, @epic, @legendary = fixture_tier_ids
  end

  def latest_best_card
    Game::LatestBestCard.call(@player, season: @season)
  end

  test "the card gained last, in one query" do
    hold(@player, @legendary, gained_at: 2.hours.ago)
    hold(@player, @epic, gained_at: 1.hour.ago)

    result = nil
    assert_queries_count(1) { result = latest_best_card }
    assert_equal @epic, result
  end

  test "a card traded away gives way to the card received in exchange" do
    hold(@player, @epic, gained_at: 2.hours.ago)
    hold(@player, @legendary, 0, gained_at: 1.hour.ago)

    conclude_trade(@player, @partner, offer: { @legendary => 1 }, request: { @common => 1 })

    assert_equal 0, Game::Holding.find_by!(player_id: @player.id, card_season_id: @legendary).quantity
    assert_equal @common, latest_best_card
  end

  test "a card received by trade after a capsule's card shows" do
    hold(@player, @legendary, gained_at: 1.hour.ago)

    conclude_trade(@player, @partner, offer: { @common => 1 }, request: { @epic => 1 })

    assert_equal @epic, latest_best_card
  end

  test "a card reserved in an open trade still shows" do
    hold(@player, @epic, gained_at: 1.hour.ago).update!(reserved: 1)

    assert_equal @epic, latest_best_card
  end

  test "of cards gained at the same moment, the rarer" do
    gained_at = 1.hour.ago
    hold(@player, @epic, gained_at:)
    hold(@player, @legendary, gained_at:)

    assert_equal @legendary, latest_best_card
  end

  test "a card without a gain date comes after a dated one, and shows alone" do
    hold(@player, @legendary, gained_at: nil)
    epic = hold(@player, @epic, gained_at: 1.day.ago)
    assert_equal @epic, latest_best_card

    epic.update!(quantity: 0)
    assert_equal @legendary, latest_best_card
  end

  test "a common shows when it is the card gained last, the best of a same-moment pull first" do
    gained_at = 1.minute.ago
    hold(@player, @common, gained_at:)
    hold(@player, @uncommon, gained_at:)
    hold(@player, @legendary, gained_at: 1.day.ago)

    assert_equal @uncommon, latest_best_card
  end

  test "nil for another player's cards or another season's" do
    hold(@partner, @legendary, gained_at: 1.minute.ago)
    assert_nil latest_best_card

    hold(@player, @epic, gained_at: 1.minute.ago)
    assert_nil Game::LatestBestCard.call(@player, season: publish_sets_draft)
  end

  test "nil, without a query, for a visitor or no season" do
    hold(@player, @epic, gained_at: 1.hour.ago)

    assert_queries_count(0) do
      assert_nil Game::LatestBestCard.call(nil, season: @season)
      assert_nil Game::LatestBestCard.call(@player, season: nil)
    end
  end
end

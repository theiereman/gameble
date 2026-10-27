require "test_helper"
require_relative "../../support/catalog_seeds"
require_relative "../../support/game_packs"
require_relative "../../support/game_trades"
require_relative "../../support/holdings"

class Game::LatestNotableCardTest < ActiveSupport::TestCase
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

  def latest_notable_card
    Game::LatestNotableCard.call(@player, season: @season)
  end

  test "the Epic-or-better card gained last, in one query" do
    hold(@player, @legendary, gained_at: 2.hours.ago)
    hold(@player, @epic, gained_at: 1.hour.ago)

    result = nil
    assert_queries_count(1) { result = latest_notable_card }
    assert_equal @epic, result
  end

  test "a card traded away gives way to the one gained before it" do
    hold(@player, @epic, gained_at: 2.hours.ago)
    hold(@player, @legendary, 0, gained_at: 1.hour.ago)

    conclude_trade(@player, @partner, offer: { @legendary => 1 }, request: { @common => 1 })

    assert_equal 0, Game::Holding.find_by!(player_id: @player.id, card_season_id: @legendary).quantity
    assert_equal @epic, latest_notable_card
  end

  test "a card received by trade after a capsule's card shows" do
    hold(@player, @legendary, gained_at: 1.hour.ago)

    conclude_trade(@player, @partner, offer: { @common => 1 }, request: { @epic => 1 })

    assert_equal @epic, latest_notable_card
  end

  test "a card reserved in an open trade still shows" do
    hold(@player, @epic, gained_at: 1.hour.ago).update!(reserved: 1)

    assert_equal @epic, latest_notable_card
  end

  test "of cards gained at the same moment, the rarer" do
    gained_at = 1.hour.ago
    hold(@player, @epic, gained_at:)
    hold(@player, @legendary, gained_at:)

    assert_equal @legendary, latest_notable_card
  end

  test "a card without a gain date comes after a dated one, and shows alone" do
    hold(@player, @legendary, gained_at: nil)
    epic = hold(@player, @epic, gained_at: 1.day.ago)
    assert_equal @epic, latest_notable_card

    epic.update!(quantity: 0)
    assert_equal @legendary, latest_notable_card
  end

  test "nil for cards below Epic, another player's cards or another season's" do
    [ @common, @uncommon, @rare ].each { |card_season_id| hold(@player, card_season_id, gained_at: 1.minute.ago) }
    hold(@partner, @legendary, gained_at: 1.minute.ago)
    assert_nil latest_notable_card

    hold(@player, @epic, gained_at: 1.minute.ago)
    assert_nil Game::LatestNotableCard.call(@player, season: publish_sets_draft)
  end

  test "nil, without a query, for a visitor or no season" do
    hold(@player, @epic, gained_at: 1.hour.ago)

    assert_queries_count(0) do
      assert_nil Game::LatestNotableCard.call(nil, season: @season)
      assert_nil Game::LatestNotableCard.call(@player, season: nil)
    end
  end
end

require "test_helper"

# Game::TierCounts: the copies a player holds per rarity tier in the
# published season, for the top bar's rarity counter.
class Game::TierCountsTest < ActiveSupport::TestCase
  setup do
    @player = accounts_players(:player)
  end

  def hold(player, card_season, quantity)
    Game::Holding.create!(player_id: player.id, card_season_id: catalog_card_seasons(card_season).id, quantity:)
  end

  test "the copies held per tier of the published season, in one query" do
    hold(@player, :steel_card_one, 3)
    hold(@player, :emerald_card_one, 1)
    hold(@player, :portal_one, 2)
    hold(@player, :gold_card_one, 0)
    hold(accounts_players(:moderator), :sapphire_card_one, 4)

    result = nil
    assert_queries_count(1) { result = Game::TierCounts.call(@player) }
    assert_equal({ 1 => 3, 2 => 1, 3 => 0, 4 => 2, 5 => 0 }, result)
  end

  test "zeros, without a query, for a visitor" do
    assert_queries_count(0) { assert_equal({ 1 => 0, 2 => 0, 3 => 0, 4 => 0, 5 => 0 }, Game::TierCounts.call(nil)) }
  end

  test "zeros when no season is published" do
    hold(@player, :steel_card_one, 3)
    catalog_seasons(:one).update_columns(status: "draft", published_at: nil)

    assert_equal({ 1 => 0, 2 => 0, 3 => 0, 4 => 0, 5 => 0 }, Game::TierCounts.call(@player))
  end

  test "only the newest published season counts" do
    hold(@player, :steel_card_one, 3)
    newer = Catalog::Season.create!(status: :draft, number: Catalog::Season.next_number)
    newer.update!(status: :published, published_at: Time.current)

    assert_equal 0, Game::TierCounts.call(@player).values.sum
  end
end

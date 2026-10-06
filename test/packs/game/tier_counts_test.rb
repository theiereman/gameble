require "test_helper"
require_relative "../../support/game_packs"

# Game::TierCounts: the copies a player holds per rarity tier in the
# published season, for the top bar's rarity counter.
class Game::TierCountsTest < ActiveSupport::TestCase
  include GamePacks

  setup do
    @player = accounts_players(:player)
  end

  def hold(player, card_season, quantity)
    Game::Holding.create!(player_id: player.id, card_season_id: catalog_card_seasons(card_season).id, quantity:)
  end

  test "the copies held per tier of the published season, in one query" do
    hold(@player, :common_card_one, 3)
    hold(@player, :uncommon_card_one, 1)
    hold(@player, :portal_one, 2)
    hold(@player, :legendary_card_one, 0)
    hold(accounts_players(:moderator), :rare_card_one, 4)

    result = nil
    assert_queries_count(1) { result = Game::TierCounts.call(@player) }
    assert_equal({ 1 => 3, 2 => 1, 3 => 0, 4 => 2, 5 => 0 }, result)
  end

  test "zeros, without a query, for a visitor" do
    assert_queries_count(0) { assert_equal({ 1 => 0, 2 => 0, 3 => 0, 4 => 0, 5 => 0 }, Game::TierCounts.call(nil)) }
  end

  test "zeros when no season is published" do
    hold(@player, :common_card_one, 3)
    catalog_seasons(:one).update_columns(status: "draft", published_at: nil)

    assert_equal({ 1 => 0, 2 => 0, 3 => 0, 4 => 0, 5 => 0 }, Game::TierCounts.call(@player))
  end

  test "only the newest published season counts" do
    hold(@player, :common_card_one, 3)
    newer = Catalog::Season.create!(status: :draft, number: Catalog::Season.next_number)
    newer.update!(status: :published, published_at: Time.current)

    assert_equal 0, Game::TierCounts.call(@player).values.sum
  end

  # --- Before an opening (AD-23) -------------------------------------------

  test "before an opening: the current counts minus the pack's cards, a card drawn twice counted twice" do
    hold(@player, :common_card_one, 5)
    hold(@player, :portal_one, 3)
    common, portal = catalog_card_seasons(:common_card_one).id, catalog_card_seasons(:portal_one).id
    pack = create_pack(@player, cards: [ common, portal, common, portal, common ], opened_at: 1.minute.ago)

    result = nil
    assert_queries_count(2) { result = Game::TierCounts.before_opening(@player, pack) }
    assert_equal({ 1 => 2, 2 => 0, 3 => 0, 4 => 1, 5 => 0 }, result)
  end

  test "before an opening: the cards of another season are not subtracted" do
    hold(@player, :common_card_one, 2)
    draft = Catalog::Season.create!(status: :draft, number: Catalog::Season.next_number)
    other = Catalog::CardSeason.create!(card: catalog_cards(:common_card), season: draft, prestige_score: 0.5, rating: 90, rarity: :common)
    common = catalog_card_seasons(:common_card_one).id
    pack = create_pack(@player, cards: [ other.id, other.id, other.id, other.id, common ], opened_at: 1.minute.ago)

    assert_equal({ 1 => 1, 2 => 0, 3 => 0, 4 => 0, 5 => 0 }, Game::TierCounts.before_opening(@player, pack))
  end

  test "before an opening: never below zero" do
    hold(@player, :legendary_card_one, 1)
    legendary = catalog_card_seasons(:legendary_card_one).id
    pack = create_pack(@player, cards: [ legendary ] * 5, opened_at: 1.minute.ago)

    assert_equal({ 1 => 0, 2 => 0, 3 => 0, 4 => 0, 5 => 0 }, Game::TierCounts.before_opening(@player, pack))
  end
end

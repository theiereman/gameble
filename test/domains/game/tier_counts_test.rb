require "test_helper"
require_relative "../../support/game_packs"
require_relative "../../support/holdings"

# Game::TierCounts: the copies a player holds per rarity tier, every
# edition counted, for the top bar's rarity counter.
class Game::TierCountsTest < ActiveSupport::TestCase
  include Holdings
  include GamePacks

  setup do
    @player = accounts_players(:player)
  end

  test "the copies held per tier, in one query" do
    hold(@player, catalog_card_seasons(:common_card_one).id, 3)
    hold(@player, catalog_card_seasons(:uncommon_card_one).id, 1)
    hold(@player, catalog_card_seasons(:portal_one).id, 2)
    hold(@player, catalog_card_seasons(:legendary_card_one).id, 0)
    hold(accounts_players(:moderator), catalog_card_seasons(:rare_card_one).id, 4)

    result = nil
    assert_queries_count(1) { result = Game::TierCounts.call(@player) }
    assert_equal({ 1 => 3, 2 => 1, 3 => 0, 4 => 2, 5 => 0 }, result)
  end

  test "zeros, without a query, for a visitor" do
    assert_queries_count(0) { assert_equal({ 1 => 0, 2 => 0, 3 => 0, 4 => 0, 5 => 0 }, Game::TierCounts.call(nil)) }
  end

  test "every edition counts, at the rarity it was minted in: publishing a season changes nothing" do
    hold(@player, catalog_card_seasons(:common_card_one).id, 3)
    newer = Catalog::Season.create!(status: :draft, number: Catalog::Season.next_number)
    reprint = Catalog::CardSeason.create!(card: catalog_cards(:common_card), season: newer, prestige_score: 0.5, rating: 90, rarity: :rare, number: 1)
    Game::Holding.create!(player_id: @player.id, card_season_id: reprint.id, quantity: 2)
    newer.update!(status: :published, published_at: Time.current)

    assert_equal({ 1 => 3, 2 => 0, 3 => 2, 4 => 0, 5 => 0 }, Game::TierCounts.call(@player))
  end

  # --- Before an opening -------------------------------------------

  test "before an opening: the current counts minus the pack's cards, a card drawn twice counted twice" do
    hold(@player, catalog_card_seasons(:common_card_one).id, 5)
    hold(@player, catalog_card_seasons(:portal_one).id, 3)
    common, portal = catalog_card_seasons(:common_card_one).id, catalog_card_seasons(:portal_one).id
    pack = create_pack(@player, cards: [ common, portal, common, portal, common ], opened_at: 1.minute.ago)

    result = nil
    assert_queries_count(2) { result = Game::TierCounts.before_opening(@player, pack) }
    assert_equal({ 1 => 2, 2 => 0, 3 => 0, 4 => 1, 5 => 0 }, result)
  end

  test "before an opening: the cards of every season are subtracted, at the rarity they were minted in" do
    hold(@player, catalog_card_seasons(:common_card_one).id, 2)
    newer = Catalog::Season.create!(status: :draft, number: Catalog::Season.next_number)
    other = Catalog::CardSeason.create!(card: catalog_cards(:common_card), season: newer, prestige_score: 0.5, rating: 90, rarity: :rare, number: 1)
    Game::Holding.create!(player_id: @player.id, card_season_id: other.id, quantity: 4)
    common = catalog_card_seasons(:common_card_one).id
    pack = create_pack(@player, cards: [ other.id, other.id, other.id, common, common ], opened_at: 1.minute.ago)

    assert_equal({ 1 => 0, 2 => 0, 3 => 1, 4 => 0, 5 => 0 }, Game::TierCounts.before_opening(@player, pack))
  end

  test "before an opening: never below zero" do
    hold(@player, catalog_card_seasons(:legendary_card_one).id, 1)
    legendary = catalog_card_seasons(:legendary_card_one).id
    pack = create_pack(@player, cards: [ legendary ] * 5, opened_at: 1.minute.ago)

    assert_equal({ 1 => 0, 2 => 0, 3 => 0, 4 => 0, 5 => 0 }, Game::TierCounts.before_opening(@player, pack))
  end
end

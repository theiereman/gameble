require "test_helper"
require_relative "../../support/catalog_seeds"

class Game::FriendProfileQueriesTest < ActiveSupport::TestCase
  include CatalogSeeds

  setup do
    @player = accounts_players(:player)
    @other = accounts_players(:moderator)
  end

  def befriend(one, other)
    Game::Friendship.create!(low_player_id: [ one.id, other.id ].min, high_player_id: [ one.id, other.id ].max)
  end

  def hold(card_season_id, quantity: 1, gained_at: nil, player: @player)
    Game::Holding.create!(player_id: player.id, card_season_id:, quantity:, last_gained_at: gained_at)
  end

  test "two players are friends from either side once their friendship exists" do
    assert_not Game::FriendshipBetween.call(@player, @other)

    befriend(@player, @other)

    assert Game::FriendshipBetween.call(@player, @other)
    assert Game::FriendshipBetween.call(@other, @player)
    assert_not Game::FriendshipBetween.call(@player, accounts_players(:administrator))
  end

  test "a visitor or the player themselves is no friend, without a query" do
    assert_no_queries do
      assert_not Game::FriendshipBetween.call(nil, @player)
      assert_not Game::FriendshipBetween.call(@player, nil)
      assert_not Game::FriendshipBetween.call(@player, @player)
    end
  end

  test "the showcase is the three highest-tier cards held, the latest gained first on a tie" do
    season = publish_sets_draft
    tiers = Catalog::CardSeason.where(season_id: season.id).order(:id).pluck(:rarity, :id)
      .group_by(&:first).transform_values { |rows| rows.map(&:last) }
    legendary = tiers.fetch("legendary").first
    epic_old, epic_new = tiers.fetch("epic").first(2)
    rare = tiers.fetch("rare").first
    hold(rare, quantity: 4, gained_at: 1.minute.ago)
    hold(epic_old, gained_at: 2.days.ago)
    hold(epic_new, gained_at: 1.day.ago)
    hold(legendary, gained_at: 3.days.ago)
    hold(tiers.fetch("legendary").second, quantity: 0, gained_at: 1.minute.ago)

    result = nil
    assert_queries_count(1) { result = Game::ShowcaseCards.call(@player, season:) }
    assert_equal [ legendary, epic_new, epic_old ], result
  end

  test "fewer cards show when fewer are held, only the season's, none for a visitor or no season" do
    season = publish_sets_draft
    first = Catalog::CardSeason.where(season_id: season.id).order(:id).first.id
    other_season = seed_card_seasons([ 1 ])
    hold(first)
    hold(Catalog::CardSeason.find_by!(season_id: other_season.id).id)
    hold(first, player: @other)

    assert_equal [ first ], Game::ShowcaseCards.call(@player, season:)
    assert_no_queries do
      assert_equal [], Game::ShowcaseCards.call(nil, season:)
      assert_equal [], Game::ShowcaseCards.call(@player, season: nil)
    end
  end
end

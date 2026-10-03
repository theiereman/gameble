require "test_helper"
require_relative "../../support/catalog_seeds"

# Game::StartedSets (CAP-8): the sets of which a player holds a card.
class Game::StartedSetsTest < ActiveSupport::TestCase
  include CatalogSeeds

  setup do
    @season = publish_sets_draft
    @sets = Catalog::Set.where(season_id: @season.id).index_by(&:key)
    @player = accounts_players(:player)
  end

  def members(key)
    Catalog::SetMembership.where(set_id: @sets.fetch(key).id).order(:position).pluck(:card_season_id)
  end

  def hold(player, card_season_id, quantity)
    Game::Holding.create!(player_id: player.id, card_season_id:, quantity:)
  end

  def started(player)
    Game::StartedSets.relation(player, Catalog::SeasonShelf.every_kind(season: @season)).map(&:key)
  end

  test "the sets with a card the player holds, in the order of the relation given" do
    held = [ members("p").first, members("rpg-1").last ]
    held.each { |id| hold(@player, id, 2) }
    hold(accounts_players(:moderator), members("action-2").first, 1)

    expected = Catalog::SeasonShelf.every_kind(season: @season).map(&:key).select { |key| (members(key) & held).any? }
    assert_includes expected, "p"
    assert_includes expected, "rpg-1"
    assert_equal expected, started(@player)
  end

  test "a card held at 0 starts nothing, and another player's cards are theirs" do
    hold(@player, members("action-3").first, 0)
    hold(accounts_players(:moderator), members("action-2").first, 1)

    assert_empty started(@player)
    assert_includes started(accounts_players(:moderator)), "action-2"
  end

  test "a player with no card, or a visitor, has started nothing" do
    assert_empty started(@player)
    assert_queries_count(0) { assert_empty Game::StartedSets.relation(nil, Catalog::Set.all).to_a }
  end

  test "the relation stays lazy: its count and a page are one query each" do
    hold(@player, members("p").first, 1)

    relation = nil
    assert_queries_count(0) { relation = Game::StartedSets.relation(@player, Catalog::SeasonShelf.every_kind(season: @season)) }
    assert_queries_count(1) { assert_operator relation.count, :>=, 2 }
    assert_queries_count(1) { relation.limit(50).offset(0).to_a }
  end
end

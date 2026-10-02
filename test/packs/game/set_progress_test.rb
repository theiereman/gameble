require "test_helper"
require_relative "../../support/catalog_seeds"

# Game::SetProgress (CAP-6): a player's distinct owned cards per set.
class Game::SetProgressTest < ActiveSupport::TestCase
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

  def progress(player, *keys)
    Game::SetProgress.call(player, @sets.values_at(*keys).map(&:id)).transform_keys { |id| @sets.values.find { |set| set.id == id }.key }
  end

  test "a player owning 3 of a tome's cards, one twice, has 3 of it" do
    first, second, third = members("action-1").first(3)
    hold(@player, first, 1)
    hold(@player, second, 2)
    hold(@player, third, 1)

    assert_equal({ "action-1" => 3 }, progress(@player, "action-1", "action-2"))
  end

  test "a card in a publisher set and a tome counts in both" do
    card = members("p").first
    tome = @sets.values.find { |set| set.kind == "tome" && members(set.key).include?(card) }
    hold(@player, card, 1)

    assert_equal({ "p" => 1, tome.key => 1 }, progress(@player, "p", tome.key))
  end

  test "a holding at 0 is not counted" do
    hold(@player, members("rpg-1").first, 0)

    assert_equal({}, progress(@player, "rpg-1"))
  end

  test "another player's cards are theirs, and only the sets asked about are answered" do
    hold(accounts_players(:moderator), members("rpg-1").first, 1)
    hold(@player, (members("rpg-1") - members("2011")).last, 1)

    assert_equal({ "rpg-1" => 1 }, progress(accounts_players(:moderator), "rpg-1"))
    assert_equal({ "rpg-1" => 1 }, progress(@player, "rpg-1", "2011"))
    assert_equal({}, progress(@player, "2011", "p"))
  end

  test "one query for a player, none for a visitor or no set" do
    hold(@player, members("p").first, 1)
    ids = @sets.values.map(&:id)

    assert_queries_count(1) { Game::SetProgress.call(@player, ids) }
    assert_queries_count(0) { assert_equal({}, Game::SetProgress.call(nil, ids)) }
    assert_queries_count(0) { assert_equal({}, Game::SetProgress.call(@player, [])) }
  end
end

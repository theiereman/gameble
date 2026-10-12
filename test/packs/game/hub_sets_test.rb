require "test_helper"
require_relative "../../support/catalog_seeds"

# Game::HubSets: the hub's set progress rows, the sets a player has started
# first, filled with sets not started yet.
class Game::HubSetsTest < ActiveSupport::TestCase
  include CatalogSeeds

  setup do
    @season = publish_sets_draft
    @sets = Catalog::Set.where(season_id: @season.id).index_by(&:key)
    @player = accounts_players(:player)
  end

  def members(key)
    Catalog::SetMembership.where(set_id: @sets.fetch(key).id).order(:position).pluck(:card_season_id)
  end

  def hold(player, card_season_id, quantity = 1)
    Game::Holding.create!(player_id: player.id, card_season_id:, quantity:)
  end

  def rows(player = @player, limit: 4)
    Game::HubSets.call(player, season: @season, limit:).map { |row| [ row.set.key, row.owned, row.total ] }
  end

  # The same answer, worked out in Ruby from every set of the season.
  def expected(held, limit: 4)
    progress = @sets.values.map { |set| [ set, (members(set.key) & held).size, members(set.key).size ] }
    started = progress.select { |_set, owned, _total| owned.positive? }
      .sort_by { |set, owned, total| [ owned >= total ? 1 : 0, -owned.fdiv(total), -owned, set.id ] }.first(limit)
    fill = progress.reject { |_set, owned, _total| owned.positive? }
      .sort_by { |set, _owned, _total| [ set.kind == "theme" ? 0 : 1, set.id ] }.first(limit - started.size)
    (started + fill).map { |set, owned, total| [ set.key, owned, total ] }
  end

  test "started sets first, in progress before complete, then by share and count owned" do
    held = members("pirates") + (members("rpg") - members("pirates")).first(2) + (members("roguelike") - members("pirates")).first(1)
    held.uniq.each { |id| hold(@player, id) }
    hold(accounts_players(:moderator), members("ufos").first)

    result = rows(limit: 50)
    assert_equal expected(held.uniq, limit: 50), result
    complete = result.index { |key, owned, total| owned == total }
    assert result.first(complete).all? { |_key, owned, total| owned < total }, "complete sets come after those in progress"
    assert_includes result.map(&:first), "pirates"
  end

  test "a player with fewer than four started sets is filled with unstarted ones at 0, themes first" do
    hold(@player, members("ufos").first)

    result = rows
    assert_equal 4, result.size
    assert_equal expected([ members("ufos").first ]), result
    unstarted = result.select { |_key, owned, _total| owned.zero? }.map(&:first)
    assert unstarted.all? { |key| @sets.fetch(key).kind == "theme" }, "the fill starts with themes"
  end

  test "a holding at 0 does not start a set" do
    hold(@player, members("ufos").first, 0)

    assert_equal expected([]), rows
  end

  test "a visitor gets the fill only, in two queries" do
    result = nil
    assert_queries_count(2) { result = rows(nil) }
    assert_equal expected([]), result
    assert result.all? { |_key, owned, _total| owned.zero? }
  end

  test "a player who started four sets or more gets them in two queries" do
    (members("pirates") + members("ufos") + members("rpg").first(1)).uniq.each { |id| hold(@player, id) }

    result = nil
    assert_queries_count(2) { result = rows }
    assert_equal 4, result.size
    assert result.all? { |_key, owned, _total| owned.positive? }
  end

  test "another season's sets never show, and no season gives no row" do
    hold(@player, catalog_card_seasons(:portal_one).id)

    assert_not_includes rows.map(&:first), "valve"
    assert_queries_count(0) { assert_equal [], Game::HubSets.call(@player, season: nil) }
  end
end

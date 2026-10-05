require "test_helper"
require_relative "../../support/catalog_seeds"

# Game::NotablePull: the hub showcase's card, the player's latest pull of
# tier 4 or above in the published season.
class Game::NotablePullTest < ActiveSupport::TestCase
  include CatalogSeeds

  setup do
    @season = publish_sets_draft
    @player = accounts_players(:player)
    # The published season's card-season ids by tier (1 to 5), by id.
    @tiers = Catalog::CardSeason.where(season_id: @season.id).order(:id).pluck(:rarity, :id)
      .group_by { |rarity, _id| Catalog::CardSeason.rarities.fetch(rarity) }.transform_values { |rows| rows.map(&:last) }
  end

  def tier(number, index = 0)
    @tiers.fetch(number).fetch(index)
  end

  def open_pack(cards, opened_at:, player: @player, season: @season)
    Game::Pack.create!(player_id: player.id, kind: :regular, season_id: season.id, card_season_ids: cards,
      available_at: opened_at - 1.hour, opened_at:)
  end

  test "the most recently opened pack holding a tier 4 card wins, not a later pack of lower tiers" do
    open_pack([ tier(3), tier(4), tier(1), tier(1), tier(2) ], opened_at: Time.zone.parse("2026-10-05 10:00"))
    open_pack(Array.new(5) { |index| tier(1, index) }, opened_at: Time.zone.parse("2026-10-05 11:00"))

    result = nil
    assert_queries_count(1) { result = Game::NotablePull.call(@player) }
    assert_equal tier(4), result
  end

  test "within that pack, the highest tier, then the first drawn" do
    open_pack([ tier(4, 1), tier(1), tier(4, 0), tier(1), tier(2) ], opened_at: 2.hours.ago)
    assert_equal tier(4, 1), Game::NotablePull.call(@player)

    open_pack([ tier(4), tier(1), tier(5), tier(1), tier(2) ], opened_at: 1.hour.ago)
    assert_equal tier(5), Game::NotablePull.call(@player)
  end

  test "an unopened pack, another player's pack and an older season's card are not pulls" do
    Game::Pack.create!(player_id: @player.id, kind: :regular, season_id: @season.id,
      card_season_ids: Array.new(5, tier(5)), available_at: 1.hour.ago)
    open_pack(Array.new(5, tier(5)), opened_at: 1.hour.ago, player: accounts_players(:moderator))
    old = Catalog::CardSeason.where(season_id: catalog_seasons(:one).id).where("rarity = 5").pick(:id)
    open_pack(Array.new(5, old), opened_at: 1.minute.ago, season: catalog_seasons(:one))

    assert_nil Game::NotablePull.call(@player)
  end

  test "a pull older than the latest packs looked at first is found by a second query" do
    open_pack([ tier(1), tier(4), tier(1), tier(1), tier(1) ], opened_at: 1.day.ago)
    common = Array.new(5) { |index| tier(1, index) }
    Game::NotablePull::RECENT.times { |index| open_pack(common, opened_at: (index + 1).minutes.ago) }

    result = nil
    assert_queries_count(2) { result = Game::NotablePull.call(@player) }
    assert_equal tier(4), result
  end

  test "nil, without a query, for a visitor; nil for a player who never pulled tier 4" do
    open_pack(Array.new(5) { |index| tier(3, index) }, opened_at: 1.hour.ago)

    assert_queries_count(0) { assert_nil Game::NotablePull.call(nil) }
    assert_nil Game::NotablePull.call(@player)
  end
end

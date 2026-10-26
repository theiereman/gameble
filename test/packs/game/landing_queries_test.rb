require "test_helper"

class Game::LandingQueriesTest < ActiveSupport::TestCase
  NOW = Time.utc(2026, 10, 14, 12, 0)
  WEEK = Date.new(2026, 10, 12)

  setup do
    @player = accounts_players(:player)
    @other = accounts_players(:moderator)
  end

  def open_pack(player, at)
    card = catalog_card_seasons(:portal_one).id
    row = Game::Pack.row(player_id: player.id, kind: :regular, season_id: catalog_seasons(:one).id, card_season_ids: [ card ] * 5, available_at: at - 1.hour)
    Game::Pack.insert_all!([ row.merge(opened_at: at) ], returning: :id).rows.flatten.first
  end

  def contribute(player, openings: 0, trades: 0, week: WEEK)
    Game::WeeklyContribution.insert!({ player_id: player.id, week_start: week, openings:, trades: })
  end

  def discover(card_name, pack_id, at)
    Game::FirstDiscovery.insert!({ card_season_id: catalog_card_seasons(card_name).id, player_id: @player.id, pack_id:, discovered_at: at })
  end

  def with_memory_cache
    original = Rails.cache
    Rails.cache = ActiveSupport::Cache::MemoryStore.new
    yield
  ensure
    Rails.cache = original
  end

  test "an empty game counts zero and keeps the published season" do
    Game::FirstDiscovery.delete_all
    facts = Game::LandingSeasonFacts.call(locale: :en, now: NOW)

    assert_equal({ season_number: catalog_seasons(:one).number, players: 0, packs: 0, discoveries: 0 }, facts)
  end

  test "players are those who opened a pack in the goal's week, packs those opened in the UTC day" do
    contribute(@player, openings: 2)
    contribute(@other, trades: 3)
    contribute(@other, openings: 5, week: WEEK - 7)
    open_pack(@player, Time.utc(2026, 10, 14, 0, 0))
    open_pack(@player, Time.utc(2026, 10, 13, 23, 59, 59))

    facts = Game::LandingSeasonFacts.call(locale: :en, now: NOW)

    assert_equal 1, facts[:players]
    assert_equal 1, facts[:packs]
  end

  test "discoveries count from Monday 00:00 UTC of the week" do
    Game::FirstDiscovery.delete_all
    inside = open_pack(@player, Time.utc(2026, 10, 12, 0, 0))
    discover(:portal_one, inside, Time.utc(2026, 10, 12, 0, 0))
    discover(:common_card_one, inside, Time.utc(2026, 10, 11, 23, 59, 59))

    assert_equal 1, Game::LandingSeasonFacts.call(locale: :en, now: NOW)[:discoveries]
  end

  test "no published season gives no season number" do
    Catalog::Season.update_all(status: "draft")

    assert_nil Game::LandingSeasonFacts.call(locale: :en, now: NOW)[:season_number]
  end

  test "the goal carries its total, target and the players whose contributions are above zero" do
    contribute(@player, openings: 1)
    contribute(@other, trades: 1)
    contribute(accounts_players(:administrator), openings: 0, trades: 0)
    Game::WeeklyGoal.insert!({ week_start: WEEK, total: 30, target: 200 })

    assert_equal({ total: 30, target: 200, participants: 2 }, Game::LandingGoal.call(locale: :en, now: NOW))
  end

  test "an empty game has an empty goal" do
    goal = Game::LandingGoal.call(locale: :en, now: NOW)

    assert_equal [ 0, 0 ], [ goal[:total], goal[:participants] ]
  end

  test "a second call within the lifetime runs no query, in either block" do
    with_memory_cache do
      Game::LandingSeasonFacts.call(locale: :fr, now: NOW)
      Game::LandingGoal.call(locale: :fr, now: NOW)

      queries = []
      callback = ->(*, payload) { queries << payload[:sql] unless payload[:name] == "SCHEMA" }
      ActiveSupport::Notifications.subscribed(callback, "sql.active_record") do
        Game::LandingSeasonFacts.call(locale: :fr, now: NOW)
        Game::LandingGoal.call(locale: :fr, now: NOW)
      end

      assert_empty queries
    end
  end
end

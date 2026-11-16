require "test_helper"

class Game::MarkProfileVisitedTest < ActiveSupport::TestCase
  include ActiveJob::TestHelper
  NOW = Time.utc(2026, 11, 16, 12, 0)

  setup do
    @viewer = accounts_players(:player)
    @owner = accounts_players(:moderator)
    @other = accounts_players(:administrator)
    [ @owner, @other ].each { it.update!(visibility: :public) }
  end

  def visit(owner = @owner, now: NOW, viewer: @viewer) = Game::MarkProfileVisited.new.call(player: viewer, owner_token: owner.token, now:)

  def visits = Game::ProfileVisit.where(viewer_id: @viewer.id)

  def events = Rails.configuration.event_store.read.of_type([ Game::ProfileVisited ]).to_a

  test "a first visit re-checks both players, who earn their first achievements" do
    perform_enqueued_jobs { visit.value! }

    assert Game::AchievementUnlock.exists?(player_id: @viewer.id, achievement: "profiles_viewed_1")
  end

  test "a first visit writes a row and one event naming both players" do
    assert visit.success?

    assert_equal [ [ @viewer.id, @owner.id ] ], visits.pluck(:viewer_id, :visited_id)
    assert_equal [ { viewer_id: @viewer.id, visited_id: @owner.id } ], events.map(&:data)
  end

  test "the same pair within the hour is refused without a row or an event" do
    visit

    assert_equal :recently_visited, visit(now: NOW + 20.minutes).failure
    assert_equal 1, visits.count
    assert_equal 1, events.size
  end

  test "the same pair after the hour counts again" do
    visit

    assert visit(now: NOW + 61.minutes).success?
    assert_equal 2, visits.count
  end

  test "another profile within the hour counts" do
    visit

    assert visit(@other, now: NOW + 5.minutes).success?
    assert_equal 2, visits.count
  end

  test "one's own profile writes nothing" do
    assert_equal :profile_not_found, visit(@viewer).failure
    assert_equal 0, Game::ProfileVisit.count
  end

  test "a private, friends-only, banned or deleted profile writes nothing" do
    @owner.update!(visibility: :private)
    assert_equal :profile_not_found, visit.failure

    @owner.update!(visibility: :friends_only)
    assert_equal :profile_not_found, visit.failure

    @owner.update!(visibility: :public, banned_at: Time.current)
    assert_equal :profile_not_found, visit.failure

    assert_equal 0, Game::ProfileVisit.count
    assert_empty events
  end

  test "an unknown token writes nothing" do
    assert_equal :profile_not_found, Game::MarkProfileVisited.new.call(player: @viewer, owner_token: "nope", now: NOW).failure
  end

  test "the metrics count views made and visits received" do
    visit
    visit(@other)
    Game::ProfileVisit.create!(viewer_id: @other.id, visited_id: @owner.id, created_at: NOW)

    assert_equal 2, Game::AchievementProgress.call(@viewer, [ :profiles_viewed ]).fetch(:profiles_viewed)
    assert_equal 2, Game::AchievementProgress.call(@owner, [ :profile_visits ]).fetch(:profile_visits)
    assert_equal 0, Game::AchievementProgress.call(@viewer, [ :profile_visits ]).fetch(:profile_visits)
  end

  test "releasing a player deletes the visits they made and received" do
    visit
    visit(@other)
    Game::ProfileVisit.create!(viewer_id: @other.id, visited_id: @viewer.id, created_at: NOW)

    assert Game::ReleasePlayer.new.call(player: @viewer).success?

    assert_equal 0, Game::ProfileVisit.count
  end

  test "the export counts both directions" do
    visit
    Game::ProfileVisit.create!(viewer_id: @other.id, visited_id: @viewer.id, created_at: NOW)

    markers = Game::ExportOf.call(@viewer).markers

    assert_equal [ 1, 1 ], [ markers.profiles_viewed, markers.profile_visits ]
  end
end

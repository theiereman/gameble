require "test_helper"
require_relative "../../support/lock_races"

# Two containers booting at once both run Catalog::CreateRoadmapMilestones:
# the milestones table lock makes the second wait, then find every epic
# known. Each thread has its own connection, so the test commits for real
# and removes its milestones and their events.
class Catalog::CreateRoadmapMilestonesConcurrencyTest < ActiveSupport::TestCase
  include LockRaces

  self.use_transactional_tests = false

  teardown do
    connection = ActiveRecord::Base.connection
    stream = Catalog::RoadmapMilestone.stream_name
    event_ids = connection.select_values(ActiveRecord::Base.sanitize_sql_array([ "SELECT event_id FROM event_store_events_in_streams WHERE stream = ?", stream ]))
    connection.exec_delete(ActiveRecord::Base.sanitize_sql_array([ "DELETE FROM event_store_events_in_streams WHERE stream = ?", stream ]))
    connection.exec_delete(ActiveRecord::Base.sanitize_sql_array([ "DELETE FROM event_store_events WHERE event_id IN (?)", event_ids ])) if event_ids.any?
    Catalog::RoadmapMilestone.delete_all
  end

  def create = -> { Catalog::CreateRoadmapMilestones.new.call(epics:) }

  def epics = %w[epic-one epic-two epic-three].map { Catalog::InitiativeEpics::Epic.new(slug: it, title: it) }

  test "the second run waits for the first and creates nothing: no duplicate, no shared position" do
    first, second = first_holding_the_lock(create, create)

    assert_equal 3, first.value!.size
    assert_equal [], second.value!
    assert_equal [ [ "epic-one", 1 ], [ "epic-two", 2 ], [ "epic-three", 3 ] ], Catalog::RoadmapMilestone.ordered.pluck(:epic_slug, :position)
  end

  test "runs started at once create each milestone once" do
    results = together(create, create, create)

    assert_equal [ 3, 0, 0 ], results.map { it.value!.size }.sort.reverse
    assert_equal (1..3).to_a, Catalog::RoadmapMilestone.ordered.pluck(:position)
  end
end

require "test_helper"
require_relative "../support/rake_tasks"

# catalog:create_roadmap_milestones, run on every web container boot: one
# hidden milestone per epic of the initiative's file that has none, and a
# warning, never a failure, when the file cannot be read.
class CatalogCreateRoadmapMilestonesTaskTest < ActiveSupport::TestCase
  include RakeTasks

  setup { rake_task("catalog:create_roadmap_milestones") }

  def run_task
    rake_task("catalog:create_roadmap_milestones").execute
  end

  def with_reading(reading)
    original = Catalog::InitiativeEpics.method(:read).unbind
    Catalog::InitiativeEpics.singleton_class.define_method(:read) { |_path| reading }
    yield
  ensure
    Catalog::InitiativeEpics.singleton_class.define_method(:read, original)
  end

  test "the first run creates a hidden milestone per initiative epic in the file's order; the second creates nothing" do
    epics = Catalog::InitiativeEpics.read(Rails.root.join("_bmad-output/initiative-gameble/tickets.toml")).epics

    output, = capture_io { run_task }

    assert_equal "catalog:create_roadmap_milestones: #{epics.size} milestones created: #{epics.map(&:slug).join(", ")}\n", output
    assert_equal epics.map { [ it.slug, it.title, it.title, "to_come", false ] },
      Catalog::RoadmapMilestone.ordered.pluck(:epic_slug, :wording_fr, :wording_en, :status, :shown)

    output, = capture_io { run_task }

    assert_equal "catalog:create_roadmap_milestones: every epic has its milestone; nothing created\n", output
    assert_equal epics.size, Catalog::RoadmapMilestone.count
  end

  test "a file that cannot be read warns, creates nothing and does not fail" do
    with_reading(Catalog::InitiativeEpics::Reading.new(epics: nil, problem: "missing: /rails/tickets.toml")) do
      output, error = capture_io { run_task }

      assert_equal "", output
      assert_equal "catalog:create_roadmap_milestones: the initiative's epics could not be read (missing: /rails/tickets.toml); no milestone created\n", error
    end
    assert_equal 0, Catalog::RoadmapMilestone.count
  end

  test "an error while creating warns and does not fail" do
    failing = Object.new
    failing.define_singleton_method(:call) { |**| raise ActiveRecord::ConnectionNotEstablished, "no database" }
    Catalog::CreateRoadmapMilestones.singleton_class.define_method(:new) { |*| failing }

    _, error = capture_io { run_task }

    assert_equal "catalog:create_roadmap_milestones: failed: ActiveRecord::ConnectionNotEstablished: no database; no milestone created\n", error
  ensure
    Catalog::CreateRoadmapMilestones.singleton_class.remove_method(:new)
  end
end

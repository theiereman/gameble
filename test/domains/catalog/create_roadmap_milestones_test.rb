require "test_helper"

# Catalog::CreateRoadmapMilestones: one hidden, "to come" milestone per epic
# that has none, after the last one, in the epics' order; existing
# milestones are never touched.
class Catalog::CreateRoadmapMilestonesTest < ActiveSupport::TestCase
  def epic(slug, title = slug.titleize) = Catalog::InitiativeEpics::Epic.new(slug:, title:)

  def create(*epics) = Catalog::CreateRoadmapMilestones.new.call(epics:)

  def roadmap_events = Rails.configuration.event_store.read.stream(Catalog::RoadmapMilestone.stream_name).to_a

  def milestones = Catalog::RoadmapMilestone.ordered.pluck(:epic_slug, :wording_fr, :wording_en, :status, :shown, :position)

  test "the first run creates one milestone per epic, in order, worded with its title, to come and hidden, with one event" do
    result = create(epic("epic-one", "Foundation"), epic("epic-two", "Steam catalog"), epic("epic-three", "Packs"))

    assert_equal [
      [ "epic-one", "Foundation", "Foundation", "to_come", false, 1 ],
      [ "epic-two", "Steam catalog", "Steam catalog", "to_come", false, 2 ],
      [ "epic-three", "Packs", "Packs", "to_come", false, 3 ]
    ], milestones
    assert_equal Catalog::RoadmapMilestone.ordered.to_a, result.value!
    assert_equal [ Catalog::RoadmapMilestonesCreated ], roadmap_events.map(&:class)
    assert_equal({ milestone_ids: Catalog::RoadmapMilestone.ordered.ids }, roadmap_events.sole.data)
    assert Catalog::RoadmapMilestone.pluck(:token).all? { it.length == 24 }
  end

  test "a rerun with every slug known creates nothing, publishes nothing and leaves staff edits and renamed epics alone" do
    create(epic("epic-one", "Foundation"), epic("epic-two", "Steam catalog"))
    Catalog::RoadmapMilestone.find_by!(epic_slug: "epic-one").update!(wording_fr: "Les fondations", status: "done", shown: true, position: 2)
    Catalog::RoadmapMilestone.find_by!(epic_slug: "epic-two").update!(position: 1)
    before = milestones

    assert_no_difference -> { roadmap_events.size } do
      assert_equal [], create(epic("epic-one", "Renamed foundation"), epic("epic-two", "Steam catalog")).value!
    end

    assert_equal before, milestones
  end

  test "an epic appended to the file lands after the current last milestone" do
    create(epic("epic-one"), epic("epic-two"))
    Catalog::RoadmapMilestone.find_by!(epic_slug: "epic-two").update!(position: 7)

    created = create(epic("epic-one"), epic("epic-two"), epic("epic-three", "Trades")).value!

    assert_equal [ "epic-three" ], created.map(&:epic_slug)
    assert_equal [ "Trades", "Trades", "to_come", false, 8 ], milestones.last.drop(1)
    assert_equal({ milestone_ids: [ created.sole.id ] }, roadmap_events.last.data)
  end

  test "an epic listed twice gets one milestone, and a title over the wording limit is cut to it" do
    long = "A" * 300

    create(epic("epic-one", long), epic("epic-one", "Again"))

    assert_equal [ "epic-one" ], Catalog::RoadmapMilestone.pluck(:epic_slug)
    assert_equal Catalog::RoadmapWording::LENGTH, Catalog::RoadmapMilestone.sole.wording_en.length
  end

  test "no epic creates nothing" do
    assert_equal [], create.value!
    assert_empty roadmap_events
  end

  test "the database refuses a second milestone for one epic and an unknown status" do
    create(epic("epic-one"))

    assert_raises(ActiveRecord::RecordNotUnique) do
      ActiveRecord::Base.transaction(requires_new: true) do
        Catalog::RoadmapMilestone.create!(epic_slug: "epic-one", wording_fr: "x", wording_en: "x", position: 2)
      end
    end
    assert_raises(ActiveRecord::CheckViolation) do
      ActiveRecord::Base.transaction(requires_new: true) do
        Catalog::RoadmapMilestone.where(epic_slug: "epic-one").update_all(status: "someday")
      end
    end
  end
end

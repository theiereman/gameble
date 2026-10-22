require "test_helper"
require_relative "../../support/roadmap_seeds"

# Catalog::CreateRoadmapStory, UpdateRoadmapStory, MoveRoadmapStory and
# DeleteRoadmapStory: staff add, edit, reorder and delete the stories under
# a milestone; every refusal writes nothing and publishes nothing.
class Catalog::RoadmapStoryEditsTest < ActiveSupport::TestCase
  include RoadmapSeeds

  setup do
    @milestone, @other = create_roadmap_milestones("epic-one", "epic-two")
  end

  def roadmap_events = Rails.configuration.event_store.read.stream(Catalog::RoadmapMilestone.stream_name).to_a

  def fields(**changes) = { wording_fr: "Un écran d'accueil", wording_en: "A landing page", status: "to_come", shown: true }.merge(changes)

  def add(wording_en, milestone: @milestone, **changes)
    Catalog::CreateRoadmapStory.new.call(milestone:, **fields(wording_fr: wording_en, wording_en:, **changes)).value!
  end

  def order(milestone = @milestone) = Catalog::RoadmapStories.call(milestone).map(&:wording_en)

  def move(story, direction) = Catalog::MoveRoadmapStory.new.call(story:, direction:)

  test "stories are added after the milestone's last one, each with one event" do
    first = add("First")
    add("Elsewhere", milestone: @other)
    second = Catalog::CreateRoadmapStory.new.call(milestone: @milestone, **fields(wording_en: " Second  ", status: "done", shown: false)).value!

    assert_equal [ [ "First", 1, true, "to_come" ], [ "Second", 2, false, "done" ] ],
      Catalog::RoadmapStories.call(@milestone).map { [ it.wording_en, it.position, it.shown, it.status ] }
    assert_equal 24, second.token.length
    assert_equal({ milestone_id: @milestone.id, story_id: first.id, change: "story_created" }, roadmap_events.second.data)
    assert_equal({ milestone_id: @milestone.id, story_id: second.id, change: "story_created" }, roadmap_events.last.data)
  end

  test "a story without a valid wording or status is refused and not added" do
    assert_no_difference [ -> { Catalog::RoadmapStory.count }, -> { roadmap_events.size } ] do
      assert_equal :invalid_wording, Catalog::CreateRoadmapStory.new.call(milestone: @milestone, **fields(wording_fr: "")).failure
      assert_equal :invalid_wording, Catalog::CreateRoadmapStory.new.call(milestone: @milestone, **fields(wording_en: "A" * 201)).failure
      assert_equal :invalid_status, Catalog::CreateRoadmapStory.new.call(milestone: @milestone, **fields(status: "later")).failure
    end
  end

  test "a story is reworded, given a status and hidden, with one event" do
    story = add("First")

    assert_equal story, Catalog::UpdateRoadmapStory.new.call(story:, **fields(wording_en: "Renamed", status: "in_progress", shown: false)).value!

    assert_equal [ "Renamed", "in_progress", false, 1 ], story.reload.slice(:wording_en, :status, :shown, :position).values
    assert_equal({ milestone_id: @milestone.id, story_id: story.id, change: "story_updated" }, roadmap_events.last.data)
  end

  test "an edit without a valid wording or status is refused and changes nothing" do
    story = add("First")

    assert_no_difference -> { roadmap_events.size } do
      assert_equal :invalid_wording, Catalog::UpdateRoadmapStory.new.call(story:, **fields(wording_en: " ")).failure
      assert_equal :invalid_status, Catalog::UpdateRoadmapStory.new.call(story:, **fields(status: nil)).failure
    end
    assert_equal "First", story.reload.wording_en
  end

  test "a story moves among its milestone's stories only, with one event per move" do
    first, _second, third = %w[First Second Third].map { add(it) }
    add("Elsewhere", milestone: @other)

    assert_equal third, move(third, "up").value!
    assert_equal %w[First Third Second], order
    assert_equal({ milestone_id: @milestone.id, story_id: third.id, change: "story_moved" }, roadmap_events.last.data)

    move(first, "down")

    assert_equal %w[Third First Second], order
    assert_equal [ 1, 2, 3 ], Catalog::RoadmapStories.call(@milestone).map(&:position)
    assert_equal %w[Elsewhere], order(@other)
  end

  test "the first story moved up and the last moved down are refused with at_edge" do
    first, last = add("First"), add("Last")

    assert_no_difference -> { roadmap_events.size } do
      assert_equal :at_edge, move(first, "up").failure
      assert_equal :at_edge, move(last, "down").failure
      assert_equal :invalid_direction, move(first, "sideways").failure
    end
    assert_equal %w[First Last], order
  end

  test "a story is deleted with one event; the others keep their order" do
    first, second, _third = %w[First Second Third].map { add(it) }

    assert_equal second, Catalog::DeleteRoadmapStory.new.call(story: second).value!

    assert_equal %w[First Third], order
    assert_equal({ milestone_id: @milestone.id, story_id: second.id, change: "story_deleted" }, roadmap_events.last.data)
    assert move(first, "down").success?
    assert_equal %w[Third First], order
  end

  test "a story deleted already is refused with story_not_found" do
    story = add("First")
    Catalog::DeleteRoadmapStory.new.call(story:)

    assert_no_difference -> { roadmap_events.size } do
      assert_equal :story_not_found, Catalog::DeleteRoadmapStory.new.call(story:).failure
    end
  end
end

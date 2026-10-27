require "test_helper"
require_relative "../../support/roadmap_seeds"

# Catalog::UpdateRoadmapMilestone and Catalog::MoveRoadmapMilestone: staff
# word, show, give a status to and reorder the milestones; every refusal
# writes nothing and publishes nothing.
class Catalog::RoadmapMilestoneEditsTest < ActiveSupport::TestCase
  include RoadmapSeeds

  setup do
    @one, @two, @three = create_roadmap_milestones("epic-one", "epic-two", "epic-three")
  end

  def roadmap_events = Rails.configuration.event_store.read.stream(Catalog::RoadmapMilestone.stream_name).to_a

  def order = Catalog::RoadmapMilestone.ordered.pluck(:epic_slug)

  def update(milestone = @two, **fields)
    Catalog::UpdateRoadmapMilestone.new.call(milestone:, **{ wording_fr: "Le catalogue", wording_en: "The catalog", status: "in_progress", shown: true }.merge(fields))
  end

  def move(milestone, direction) = Catalog::MoveRoadmapMilestone.new.call(milestone:, direction:)

  test "a milestone is reworded in both languages, given a status and shown, with one event" do
    assert_equal @two, update(wording_fr: "  Le   catalogue ", wording_en: "The catalog").value!

    assert_equal [ "Le catalogue", "The catalog", "in_progress", true, 2, "epic-two" ],
      @two.reload.slice(:wording_fr, :wording_en, :status, :shown, :position, :epic_slug).values
    assert_equal({ milestone_id: @two.id, story_id: nil, change: "milestone_updated" }, roadmap_events.last.data)
    assert_instance_of Catalog::RoadmapChanged, roadmap_events.last
  end

  test "a shown milestone is hidden again" do
    update(shown: true)
    update(shown: false)

    assert_not @two.reload.shown
  end

  {
    "a blank French wording" => { wording_fr: "   " },
    "a missing English wording" => { wording_en: nil },
    "a wording that is no text" => { wording_en: { "x" => "y" } },
    "a wording over the limit" => { wording_fr: "A" * 201 }
  }.each do |name, fields|
    test "#{name} is refused with invalid_wording" do
      assert_no_difference -> { roadmap_events.size } do
        assert_equal :invalid_wording, update(**fields).failure
      end
      assert_equal "Epic Two", @two.reload.wording_fr
    end
  end

  test "a wording of exactly the limit is taken" do
    assert update(wording_en: "A" * Catalog::RoadmapWording::LENGTH).success?
  end

  [ "someday", nil, "" ].each do |status|
    test "the status #{status.inspect} is refused with invalid_status" do
      assert_no_difference -> { roadmap_events.size } do
        assert_equal :invalid_status, update(status:).failure
      end
      assert_equal "to_come", @two.reload.status
    end
  end

  test "a milestone moves up and down, swapping with its neighbour, with one event per move" do
    assert_equal @three, move(@three, "up").value!
    assert_equal %w[epic-one epic-three epic-two], order
    assert_equal({ milestone_id: @three.id, story_id: nil, change: "milestone_moved" }, roadmap_events.last.data)

    move(@one, "down")

    assert_equal %w[epic-three epic-one epic-two], order
    assert_equal [ 1, 2, 3 ], Catalog::RoadmapMilestone.ordered.pluck(:position)
  end

  test "a move renumbers milestones whose places had gaps or ties" do
    @one.update!(position: 5)
    @two.update!(position: 5)
    @three.update!(position: 9)

    move(@three, "up")

    assert_equal [ [ "epic-one", 1 ], [ "epic-three", 2 ], [ "epic-two", 3 ] ], Catalog::RoadmapMilestone.ordered.pluck(:epic_slug, :position)
  end

  test "the first moved up and the last moved down are refused with at_edge" do
    assert_no_difference -> { roadmap_events.size } do
      assert_equal :at_edge, move(@one, "up").failure
      assert_equal :at_edge, move(@three, "down").failure
    end
    assert_equal %w[epic-one epic-two epic-three], order
  end

  test "a direction other than up or down is refused with invalid_direction" do
    [ "left", nil ].each { assert_equal :invalid_direction, move(@two, it).failure }
    assert_equal %w[epic-one epic-two epic-three], order
  end

  test "every refusal has its message in both languages" do
    %i[invalid_wording invalid_status at_edge invalid_direction story_not_found].each do |code|
      %i[en fr].each do |locale|
        message = I18n.with_locale(locale) { Catalog::UpdateRoadmapMilestone.failure_message(code, limit: 200) }
        assert_not_includes message, "translation missing", "#{locale} #{code}"
      end
    end
  end
end

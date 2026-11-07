require "test_helper"
require_relative "../../support/roadmap_seeds"

# Catalog::SaveRoadmap: staff save every milestone and story at once; a
# refusal writes nothing and publishes nothing.
class Catalog::SaveRoadmapTest < ActiveSupport::TestCase
  include RoadmapSeeds

  def roadmap_events = Rails.configuration.event_store.read.stream(Catalog::RoadmapMilestone.stream_name).to_a

  def row(wording, status: "to_come", shown: "1", token: nil, **extra)
    { "token" => token, "wording_fr" => "FR #{wording}", "wording_en" => wording, "status" => status, "shown" => shown, **extra.transform_keys(&:to_s) }.compact
  end

  def draft(**milestones) = Catalog::RoadmapDraft.from_form(milestones.transform_keys(&:to_s))

  def save(**milestones) = Catalog::SaveRoadmap.new.call(draft: draft(**milestones))

  def saved
    Catalog::RoadmapMilestone.order(:position).map do |milestone|
      [ milestone.wording_en, milestone.position, milestone.stories.order(:position).map { [ it.wording_en, it.position ] } ]
    end
  end

  test "new rows are created in the form's order, stories under their milestone, with one event" do
    result = save(new_1: row("First", stories: { "new_2" => row("One"), "new_3" => row("Two", status: "done", shown: "0") }), new_4: row("Second"))

    assert result.success?
    assert_equal [ [ "First", 1, [ [ "One", 1 ], [ "Two", 2 ] ] ], [ "Second", 2, [] ] ], saved
    assert_equal [ false ], Catalog::RoadmapStory.where(wording_en: "Two").pluck(:shown).uniq
    assert_equal "done", Catalog::RoadmapStory.find_by(wording_en: "Two").status
    assert_equal 24, Catalog::RoadmapMilestone.first.token.length
    assert_equal [ Catalog::RoadmapSaved ], roadmap_events.map(&:class)
    assert_equal result.value!, roadmap_events.last.data[:milestone_ids]
  end

  test "rows with a token are updated and reordered, and a row the draft leaves out is deleted with its stories" do
    first, second, third = create_roadmap_milestones("alpha", "beta", "gamma")
    story = add_roadmap_story(second, "kept")
    add_roadmap_story(third, "doomed")
    add_roadmap_story(second, "dropped")

    result = save(a: row("Beta renamed", token: second.token, status: "done", stories: { "s" => row("Kept", token: story.token) }),
      b: row("Alpha", token: first.token, shown: "0"), c: row("Brand new"))

    assert result.success?
    assert_equal [ [ "Beta renamed", 1, [ [ "Kept", 1 ] ] ], [ "Alpha", 2, [] ], [ "Brand new", 3, [] ] ], saved
    assert_equal second.id, Catalog::RoadmapMilestone.find_by!(token: second.token).id
    assert_equal "done", second.reload.status
    assert_not first.reload.shown
    assert_equal 0, Catalog::RoadmapStory.where(wording_en: [ "Story doomed", "Story dropped" ]).count
    assert_equal 1, Catalog::RoadmapStory.where(milestone_id: second.id).count
  end

  test "saving an empty form deletes everything" do
    add_roadmap_story(create_roadmap_milestones("alpha").first, "x")

    assert Catalog::SaveRoadmap.new.call(draft: Catalog::RoadmapDraft.from_form(nil)).success?
    assert_equal [], saved
    assert_equal 0, Catalog::RoadmapStory.count
  end

  test "a row without a valid wording or status refuses the whole save: nothing is written and no event is published" do
    milestone = create_roadmap_milestones("alpha").first

    [ row("Fine", stories: { "s" => row("") }), row("x" * 201), row("Fine", status: "someday"), row("Fine", status: nil) ].each do |bad|
      assert_no_difference [ -> { Catalog::RoadmapMilestone.count }, -> { Catalog::RoadmapStory.count }, -> { roadmap_events.size } ] do
        assert_equal :invalid_roadmap, save(kept: row("Renamed", token: milestone.token), bad: bad).failure
      end
    end
    assert_equal "Step alpha", milestone.reload.wording_en
  end

  test "the draft says which rows it refuses" do
    sent = draft(good: row("Fine", stories: { "s1" => row(""), "s2" => row("Ok", status: "later") }), bad: row("", token: nil))

    assert_equal({ "s1" => :invalid_wording, "s2" => :invalid_status, "bad" => :invalid_wording }, sent.refusals)
  end

  test "a token that is no longer on the roadmap refuses the save and keeps everything" do
    milestone = create_roadmap_milestones("alpha").first

    assert_no_difference [ -> { Catalog::RoadmapMilestone.count }, -> { roadmap_events.size } ] do
      assert_equal :row_not_found, save(a: row("Alpha", token: milestone.token), b: row("Ghost", token: "z" * 24)).failure
    end
  end

  test "a story cannot be saved under another milestone than its own" do
    first, second = create_roadmap_milestones("alpha", "beta")
    story = add_roadmap_story(first, "mine")

    assert_equal :row_not_found, save(a: row("Alpha", token: first.token), b: row("Beta", token: second.token, stories: { "s" => row("Mine", token: story.token) })).failure
    assert_equal first.id, story.reload.milestone_id
  end

  test "the same token twice is refused" do
    milestone = create_roadmap_milestones("alpha").first

    assert_equal :invalid_roadmap, save(a: row("Alpha", token: milestone.token), b: row("Again", token: milestone.token)).failure
  end

  test "wordings are cleaned and values that are not text are refused" do
    assert save(a: row("  Spaced   out  ")).success?
    assert_equal "Spaced out", Catalog::RoadmapMilestone.last.wording_en

    assert_equal :invalid_roadmap, save(b: { "wording_fr" => [ "x" ], "wording_en" => "x", "status" => "to_come", "shown" => "1" }).failure
  end
end

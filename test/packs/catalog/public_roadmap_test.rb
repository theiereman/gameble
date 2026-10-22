require "test_helper"

class Catalog::PublicRoadmapTest < ActiveSupport::TestCase
  setup do
    Rails.cache.clear
    epics = %w[alpha beta gamma delta].map { Catalog::InitiativeEpics::Epic.new(slug: it, title: it.titleize) }
    @milestones = Catalog::CreateRoadmapMilestones.new.call(epics:).value!
  end

  teardown { Rails.cache.clear }

  def show(milestone, status: "to_come", shown: true)
    Catalog::UpdateRoadmapMilestone.new.call(milestone:, wording_fr: "Étape #{milestone.epic_slug}", wording_en: "Step #{milestone.epic_slug}", status:, shown:).value!
  end

  def add_story(milestone, name, shown: true, status: "to_come")
    Catalog::CreateRoadmapStory.new.call(milestone:, wording_fr: "Récit #{name}", wording_en: "Story #{name}", status:, shown:).value!
  end

  test "lists every shown milestone, past the landing's limit, in staff order with every shown story" do
    epics = %w[a b c d e f g h].map { Catalog::InitiativeEpics::Epic.new(slug: "extra-#{it}", title: it) }
    more = Catalog::CreateRoadmapMilestones.new.call(epics:).value!
    (@milestones + more).each { show(it) }
    4.times { |index| add_story(@milestones.first, index) }

    roadmap = Catalog::PublicRoadmap.call(locale: :en)

    assert_equal 12, roadmap.size
    assert_equal 4, roadmap.first.stories.size
    assert_equal "Step alpha", roadmap.first.wording
  end

  test "leaves out hidden milestones and hidden stories" do
    show(@milestones.first)
    show(@milestones.second, shown: false)
    add_story(@milestones.first, "visible")
    add_story(@milestones.first, "hidden", shown: false)

    roadmap = Catalog::PublicRoadmap.call(locale: :en)

    assert_equal [ "Step alpha" ], roadmap.map(&:wording)
    assert_equal [ "Story visible" ], roadmap.first.stories.map(&:wording)
  end

  test "words and statuses follow the locale" do
    show(@milestones.first, status: "in_progress")
    add_story(@milestones.first, "x", status: "done")

    roadmap = Catalog::PublicRoadmap.call(locale: :fr)

    assert_equal [ "Étape alpha", "in_progress" ], [ roadmap.first.wording, roadmap.first.status ]
    assert_equal [ "Récit x", "done" ], [ roadmap.first.stories.first.wording, roadmap.first.stories.first.status ]
  end

  test "keeps a milestone without shown stories" do
    show(@milestones.first)
    add_story(@milestones.first, "hidden", shown: false)

    assert_empty Catalog::PublicRoadmap.call(locale: :en).first.stories
  end
end

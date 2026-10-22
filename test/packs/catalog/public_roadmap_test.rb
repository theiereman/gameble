require "test_helper"
require_relative "../../support/roadmap_seeds"

class Catalog::PublicRoadmapTest < ActiveSupport::TestCase
  include RoadmapSeeds

  setup do
    Rails.cache.clear
    @milestones = create_roadmap_milestones("alpha", "beta", "gamma", "delta")
  end

  teardown { Rails.cache.clear }

  test "lists every shown milestone, past the landing's limit, in staff order with every shown story" do
    more = create_roadmap_milestones(*%w[a b c d e f g h].map { "extra-#{it}" })
    (@milestones + more).each { show_roadmap_milestone(it) }
    4.times { |index| add_roadmap_story(@milestones.first, index) }

    roadmap = Catalog::PublicRoadmap.call(locale: :en)

    assert_equal 12, roadmap.size
    assert_equal 4, roadmap.first.stories.size
    assert_equal "Step alpha", roadmap.first.wording
  end

  test "leaves out hidden milestones and hidden stories" do
    show_roadmap_milestone(@milestones.first)
    show_roadmap_milestone(@milestones.second, shown: false)
    add_roadmap_story(@milestones.first, "visible")
    add_roadmap_story(@milestones.first, "hidden", shown: false)

    roadmap = Catalog::PublicRoadmap.call(locale: :en)

    assert_equal [ "Step alpha" ], roadmap.map(&:wording)
    assert_equal [ "Story visible" ], roadmap.first.stories.map(&:wording)
  end

  test "words and statuses follow the locale" do
    show_roadmap_milestone(@milestones.first, status: "in_progress")
    add_roadmap_story(@milestones.first, "x", status: "done")

    roadmap = Catalog::PublicRoadmap.call(locale: :fr)

    assert_equal [ "Étape alpha", "in_progress" ], [ roadmap.first.wording, roadmap.first.status ]
    assert_equal [ "Récit x", "done" ], [ roadmap.first.stories.first.wording, roadmap.first.stories.first.status ]
  end

  test "keeps a milestone without shown stories" do
    show_roadmap_milestone(@milestones.first)
    add_roadmap_story(@milestones.first, "hidden", shown: false)

    assert_empty Catalog::PublicRoadmap.call(locale: :en).first.stories
  end
end

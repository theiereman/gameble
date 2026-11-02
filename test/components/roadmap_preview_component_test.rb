require "test_helper"
require_relative "../support/roadmap_seeds"

class RoadmapPreviewComponentTest < ViewComponent::TestCase
  include RoadmapSeeds

  setup { Rails.cache.clear }
  teardown { Rails.cache.clear }

  def landing_section(locale)
    I18n.with_locale(locale) do
      html = ApplicationController.render(partial: "landings/roadmap", locals: { milestones: Catalog::LandingRoadmap.call(locale:) })
      Nokogiri::HTML.fragment(html).at_css("section.landing-roadmap").to_html
    end
  end

  def without_locale_segment(html) = html.gsub(%r{href="/\w+/roadmap"}, 'href="/roadmap"')

  test "it renders the section the landing renders for the same rows, in either language" do
    seed_roadmap(stories: [ [ "a", "done", true ], [ "b", "in_progress", true ], [ "c", "to_come", true ], [ "hidden", "done", false ] ])
    draft = Catalog::RoadmapMilestones.call

    %i[en fr].each do |locale|
      render_inline(RoadmapPreviewComponent.new(draft:, locale:))

      assert_equal without_locale_segment(landing_section(locale)), without_locale_segment(page.native.at_css("section.landing-roadmap").to_html), locale.to_s
      assert_selector "div.landing[lang=#{locale}] .landing-roadmap__milestone", count: 3
    end
  end

  test "it follows the draft and not the saved rows" do
    create_roadmap_milestones("alpha")
    draft = Catalog::RoadmapDraft.from_form("x" => { "wording_fr" => "Brouillon", "wording_en" => "Drafted", "status" => "done", "shown" => "1",
      "stories" => { "y" => { "wording_fr" => "R", "wording_en" => "Typed story", "status" => "in_progress", "shown" => "1" } } })

    render_inline(RoadmapPreviewComponent.new(draft:, locale: :en))

    assert_selector ".landing-roadmap__name", text: "Drafted"
    assert_selector ".landing-roadmap__milestone--done"
    assert_selector ".landing-roadmap__story--in-progress", text: "Typed story, In progress"
    assert_no_text "Step alpha"
  end

  test "hidden rows are left out, and the landing's limits apply" do
    rows = (1..9).to_h do |index|
      [ "m#{index}", { "wording_fr" => "F#{index}", "wording_en" => "E#{index}", "status" => "to_come", "shown" => (index == 2 ? "0" : "1"),
        "stories" => (1..4).to_h { |story| [ "s#{story}", { "wording_fr" => "f", "wording_en" => "S#{index}.#{story}", "status" => "to_come", "shown" => (story == 1 ? "0" : "1") } ] } } ]
    end

    render_inline(RoadmapPreviewComponent.new(draft: Catalog::RoadmapDraft.from_form(rows), locale: :en))

    assert_selector ".landing-roadmap__milestone", count: Catalog::LandingRoadmap::MILESTONE_LIMIT
    assert_no_text "E2"
    assert_selector ".landing-roadmap__milestone:first-child .landing-roadmap__story", count: Catalog::LandingRoadmap::STORY_LIMIT
    assert_text "S1.2"
    assert_no_text "S1.1"
    assert_no_selector "[style]"
  end
end

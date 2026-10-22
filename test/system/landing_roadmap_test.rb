require "application_system_test_case"

# Module 06 of the landing: the roadmap's milestones in one row on a desktop,
# a sideways-scrolling row on a phone that is one tab stop and answers the
# arrow keys.
class LandingRoadmapTest < ApplicationSystemTestCase
  PHONE = [ 390, 844 ].freeze

  setup do
    epics = %w[alpha beta gamma delta epsilon zeta].map { Catalog::InitiativeEpics::Epic.new(slug: it, title: it.titleize) }
    Catalog::CreateRoadmapMilestones.new.call(epics:).value!.zip(%w[done done in_progress to_come to_come to_come]).each do |milestone, status|
      Catalog::UpdateRoadmapMilestone.new.call(milestone:, wording_fr: "Étape #{milestone.epic_slug}", wording_en: "Step #{milestone.epic_slug}", status:, shown: true).value!
    end
  end

  def visit_roadmap(locale)
    visit home_path(locale:)
    page.execute_script("document.getElementById('landing-roadmap').scrollIntoView()")
  end

  def row_scroll_left = find(".landing-roadmap__line").evaluate_script("this.scrollLeft")

  test "on a desktop, the six milestones sit in one row and the row is no tab stop" do
    visit_roadmap(:en)

    assert_selector ".landing-roadmap__milestone", count: 6
    page.document.synchronize do
      tops = all(".landing-roadmap__milestone").map { it.evaluate_script("this.getBoundingClientRect().top") }
      raise Capybara::ExpectationNotMet, "the milestones are not in one row" unless tops.uniq.size == 1
    end
    assert_no_selector ".landing-roadmap__line[tabindex]"
  end

  test "on a phone, the row is one tab stop that scrolls with the arrow keys" do
    resize_to(*PHONE)
    visit_roadmap(:fr)

    assert_selector ".landing-roadmap__line[tabindex='0']"
    assert_equal 0, row_scroll_left
    find(".landing-roadmap__line").send_keys(:arrow_right)
    page.document.synchronize { raise Capybara::ExpectationNotMet, "the row did not scroll" unless row_scroll_left.positive? }
  end
end

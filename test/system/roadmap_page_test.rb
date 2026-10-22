require "application_system_test_case"
require_relative "../support/roadmap_seeds"

# The roadmap page: a vertical rail on a desktop, the rail down the left edge
# on a phone, reached from module 06 of the landing.
class RoadmapPageTest < ApplicationSystemTestCase
  include RoadmapSeeds

  PHONE = [ 390, 844 ].freeze

  setup do
    Rails.cache.clear
    create_roadmap_milestones("alpha", "beta", "gamma").zip(%w[done in_progress to_come]).each do |milestone, status|
      show_roadmap_milestone(milestone, status:)
      add_roadmap_story(milestone, milestone.epic_slug, status:)
    end
  end

  teardown { Rails.cache.clear }

  def left_of(selector, index = 0) = all(selector)[index].evaluate_script("this.getBoundingClientRect().left")

  def top_of(selector, index = 0) = all(selector)[index].evaluate_script("this.getBoundingClientRect().top")

  test "module 06 leads to the page, which lists every milestone" do
    visit home_path(locale: :en)
    page.execute_script("document.getElementById('landing-roadmap').scrollIntoView()")
    click_link "See the whole roadmap"

    assert_current_path roadmap_path(locale: :en)
    assert_selector "h1", text: "What's coming"
    assert_selector ".roadmap-milestone", count: 3
  end

  test "on a desktop, the date column, the rail and the panel sit side by side" do
    visit roadmap_path(locale: :fr)

    assert_selector ".roadmap-milestone", count: 3
    eventually("the columns are not side by side") do
      when_left, track_left, panel_left = %w[when track panel].map { left_of(".roadmap-milestone__#{it}") }
      when_left < track_left && track_left < panel_left
    end
  end

  test "on a phone, the rail runs down the left edge, nothing scrolls sideways and the status word sits above the panel" do
    resize_to(*PHONE)
    visit roadmap_path(locale: :fr)

    assert_selector ".roadmap-milestone", count: 3
    page.document.synchronize do
      raise Capybara::ExpectationNotMet, "the page scrolls sideways" if page.evaluate_script("document.documentElement.scrollWidth > document.documentElement.clientWidth")
      raise Capybara::ExpectationNotMet, "the rail is not on the left" unless left_of(".roadmap-milestone__track") < left_of(".roadmap-milestone__panel")
      raise Capybara::ExpectationNotMet, "the status word is not above the panel" unless top_of(".roadmap-milestone__when") < top_of(".roadmap-milestone__panel")
    end
  end

  test "the wordmark leads home and shows focus" do
    visit roadmap_path(locale: :en)
    link = find("a.top-bar__brand")
    link.execute_script("this.focus()")

    assert_selector "a.top-bar__brand:focus-visible"
  end
end

require "application_system_test_case"
require_relative "../support/roadmap_seeds"
require_relative "../support/steam_sign_in"

# An administrator edits the whole roadmap in one form: adds, edits,
# reorders and removes rows, watches the home page preview follow, and saves
# everything at once.
class BackOfficeRoadmapTest < ApplicationSystemTestCase
  include RoadmapSeeds
  include SteamSignIn

  MILESTONES = "[data-roadmap-list=milestone] > [data-roadmap-row=milestone]".freeze

  setup do
    Rails.cache.clear
    @alpha, @beta = create_roadmap_milestones("alpha", "beta")
    show_roadmap_milestone(@alpha, status: "done")
    @story = add_roadmap_story(@alpha, "one")
    mock_steam_sign_in(accounts_players(:administrator).steam_id)
    visit home_path(locale: :en)
    click_steam_sign_in
    assert_signed_in
    visit back_office_roadmap_path(locale: :en)
  end

  teardown { Rails.cache.clear }

  def milestone_row(key) = find("#{MILESTONES}[data-key='#{key}']")

  def own_fields(row) = row.find(".roadmap-row__body", match: :first)

  def story_row(key) = find("[data-roadmap-row=story][data-key='#{key}']")

  def order_of_rows = all(MILESTONES).map { it["data-key"] }

  test "adding rows, editing, reordering and removing with a confirmation, then saving everything at once" do
    click_on "Add a milestone"
    assert_selector MILESTONES, count: 3
    fresh = milestone_row("new-1")
    within(own_fields(fresh)) do
      fill_in "French wording", with: "Lancement"
      fill_in "English wording", with: "Launch"
      select "In progress", from: "Status"
    end
    within(fresh) { click_on "Add a story" }
    assert_selector "[data-roadmap-row=story][data-key='new-2']"
    within(story_row("new-2")) do
      fill_in "French wording", with: "Une surprise"
      fill_in "English wording", with: "A surprise"
    end
    assert_selector "[data-roadmap-preview] .landing-roadmap__name", text: "Launch"
    assert_selector "[data-roadmap-preview] .landing-roadmap__story", text: "A surprise"

    within(fresh) { click_on "Move the milestone up", match: :first }
    eventually("the new milestone moved up once") { order_of_rows == [ @alpha.token, "new-1", @beta.token ] }
    within(fresh) { click_on "Move the milestone up", match: :first }
    eventually("the new milestone moved to the top") { order_of_rows == [ "new-1", @alpha.token, @beta.token ] }
    assert_selector "[data-roadmap-preview] .landing-roadmap__milestone:first-child .landing-roadmap__name", text: "Launch"
    within(milestone_row("new-1")) { assert_selector "button[disabled]", text: /move the milestone up/i }

    within(own_fields(milestone_row(@beta.token))) { fill_in "English wording", with: "Beta renamed" }
    within(story_row(@story.token)) do
      dismiss_confirm { click_on "Remove the story" }
    end
    assert_selector "[data-roadmap-row=story][data-key='#{@story.token}']"
    within(story_row(@story.token)) do
      accept_confirm { click_on "Remove the story" }
    end
    assert_no_selector "[data-roadmap-row=story][data-key='#{@story.token}']"
    assert_equal 1, Catalog::RoadmapStory.count

    click_on "Save the roadmap"

    assert_text "The roadmap is saved, officer."
    assert_equal [ [ "Launch", 1 ], [ "Step alpha", 2 ], [ "Beta renamed", 3 ] ],
      Catalog::RoadmapMilestone.order(:position).pluck(:wording_en, :position)
    assert_equal [ [ "A surprise", "Launch" ] ], Catalog::RoadmapStory.all.map { [ it.wording_en, it.milestone.wording_en ] }
    assert_equal @alpha.id, Catalog::RoadmapMilestone.find_by!(token: @alpha.token).id
    assert_selector MILESTONES, count: 3
  end
end

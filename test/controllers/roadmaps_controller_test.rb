require "test_helper"
require_relative "../support/steam_sign_in"

class RoadmapsControllerTest < ActionDispatch::IntegrationTest
  include SteamSignIn

  setup { Rails.cache.clear }
  teardown { Rails.cache.clear }

  def seed_roadmap
    epics = %w[alpha beta gamma delta].map { Catalog::InitiativeEpics::Epic.new(slug: it, title: it.titleize) }
    milestones = Catalog::CreateRoadmapMilestones.new.call(epics:).value!
    shown = milestones.first(3)
    shown.zip(%w[done in_progress to_come]).each do |milestone, status|
      Catalog::UpdateRoadmapMilestone.new.call(milestone:, wording_fr: "Étape #{milestone.epic_slug}", wording_en: "Step #{milestone.epic_slug}", status:, shown: true).value!
    end
    [ [ "a", "done", true ], [ "b", "in_progress", true ], [ "c", "to_come", true ], [ "d", "to_come", true ], [ "hidden", "done", false ] ].each do |name, status, visible|
      Catalog::CreateRoadmapStory.new.call(milestone: shown.first, wording_fr: "Récit #{name}", wording_en: "Story #{name}", status:, shown: visible).value!
    end
    shown
  end

  test "lists every shown milestone and story with their statuses in text, in French" do
    seed_roadmap

    get roadmap_path(locale: :fr)

    assert_response :success
    assert_select "h1", count: 1, text: "Les changements à venir"
    assert_select "ol.roadmap-rail[aria-label=?]", "Étapes de la feuille de route, des plus anciennes aux plus lointaines"
    assert_equal [ "Étape alpha", "Étape beta", "Étape gamma" ], css_select("ol.roadmap-rail > li h2").map(&:text)
    assert_equal [ "Fait", "En cours", "À venir" ], css_select(".roadmap-badge").map { it.text.squish }
    stories = css_select(".roadmap-story").map { it.text.squish }
    assert_equal [ "Récit a Fait", "Récit b En cours", "Récit c À venir", "Récit d À venir" ], stories
    assert_select "title", "Feuille de route · gameble"
    assert_select "meta[name=description]"
  end

  test "reads in English" do
    seed_roadmap

    get roadmap_path(locale: :en)

    assert_select "h1", "What's coming"
    assert_select ".roadmap-page__kicker", "Roadmap"
    assert_select ".roadmap-milestone--to-come .roadmap-badge", text: "Upcoming"
    assert_select "ol.roadmap-rail[aria-label=?]", "Roadmap milestones, from the oldest to the most distant"
  end

  test "hides the hidden milestones and stories" do
    seed_roadmap

    get roadmap_path(locale: :en)

    assert_select "h2", text: "Step delta", count: 0
    assert_select ".roadmap-story", text: /hidden/, count: 0
  end

  test "a milestone without shown stories ends after its title" do
    seed_roadmap

    get roadmap_path(locale: :en)

    assert_select "ol.roadmap-rail > li:nth-child(2) .roadmap-stories", 0
    assert_select ".roadmap-stories", 1
  end

  test "the rail, nodes and markers are hidden from assistive technology" do
    seed_roadmap

    get roadmap_path(locale: :en)

    assert_select ".roadmap-milestone__track[aria-hidden=true]", 3
    assert_select ".roadmap-story__marker[aria-hidden=true]", 4
    assert_select ".roadmap-milestone__corner[aria-hidden=true]", 6
    assert_select "[style]", 0
  end

  test "a single milestone renders its node and line" do
    seed_roadmap.drop(1).each { Catalog::UpdateRoadmapMilestone.new.call(milestone: it, wording_fr: "x", wording_en: "x", status: "to_come", shown: false).value! }
    Rails.cache.clear

    get roadmap_path(locale: :en)

    assert_select ".roadmap-milestone", 1
    assert_select ".roadmap-milestone__node", 1
    assert_select ".roadmap-milestone__line", 1
  end

  test "carries the landing footer and no motion switch" do
    get roadmap_path(locale: :en)

    assert_select "footer.landing-footer"
    assert_select ".motion-switch", 0
  end

  test "a signed-in player reads it too" do
    seed_roadmap
    sign_in(accounts_players(:player))

    get roadmap_path(locale: :en)

    assert_response :success
    assert_select "h2", text: "Step alpha"
  end

  test "an older browser still reads it" do
    get roadmap_path(locale: :en), headers: { "User-Agent" => "Mozilla/5.0 (Windows NT 10.0; Win64; x64; rv:60.0) Gecko/20100101 Firefox/60.0" }

    assert_response :success
  end

  test "module 06 links to it with or without milestones" do
    get home_path(locale: :fr)
    assert_select "a.landing-roadmap__all[href=?]", roadmap_path(locale: :fr), text: "Voir toute la feuille de route"

    seed_roadmap
    Rails.cache.clear
    get home_path(locale: :en)
    assert_select "a.landing-roadmap__all[href=?]", roadmap_path(locale: :en), text: "See the whole roadmap"
  end
end

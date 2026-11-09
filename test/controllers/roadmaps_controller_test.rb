require "test_helper"
require_relative "../support/roadmap_seeds"
require_relative "../support/steam_sign_in"

class RoadmapsControllerTest < ActionDispatch::IntegrationTest
  include RoadmapSeeds
  include SteamSignIn

  setup { Rails.cache.clear }
  teardown { Rails.cache.clear }

  def seed_roadmap
    super(stories: [ [ "a", "done", true ], [ "b", "in_progress", true ], [ "c", "to_come", true ], [ "d", "to_come", true ], [ "hidden", "done", false ] ])
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
    assert_select "title", "Feuille de route · Gameble"
    assert_select "meta[name=description]"
  end

  test "hides the hidden milestones and stories" do
    seed_roadmap

    get roadmap_path(locale: :en)

    assert_select "h2", text: "Step delta", count: 0
    assert_select ".roadmap-story", text: /hidden/, count: 0
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
    assert_select ".landing-roadmap__links a[href=?]", roadmap_path(locale: :fr), text: "Voir toute la feuille de route"

    seed_roadmap
    Rails.cache.clear
    get home_path(locale: :en)
    assert_select ".landing-roadmap__links a[href=?]", roadmap_path(locale: :en), text: "See the whole roadmap"
  end
end

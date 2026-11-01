require "test_helper"
require_relative "../support/custom_sets"
require_relative "../support/game_sets"
require_relative "../support/library_requests"
require_relative "../support/steam_sign_in"

# The owner's goals on their public profile: OBJECTIFS lists the goals on
# game sets alone, in number order, as goal rows without their bookmark, each
# opening the owner's album of that set; it shows wherever the profile shows.
class PublicProfileGoalsTest < ActionDispatch::IntegrationTest
  include CustomSets
  include GameSets
  include LibraryRequests
  include SteamSignIn

  def sign_in_origin = "/fr"

  setup do
    @owner = accounts_players(:player)
    @common = catalog_card_seasons(:common_card_one).id
  end

  def add(**aim) = Game::AddGoal.new.call(player: @owner, **aim).value!

  def roguelike = insert_set([ @common, *unheld_cards(4) ], { novice: 3, complete: 5 }, key: "roguelike", params: { "theme" => "roguelike" })

  def rows = css_select("#profile-goals-heading + .goals__list > li > a.goal-row")

  def aim_at_mixed_sets
    roguelike
    hold(@owner, @common)
    add(custom_set: create_custom_set(@owner).token)
    add(kind: "theme", key: "roguelike")
    add(kind: "studio", key: "valve")
  end

  def befriend(player)
    Game::Friendship.create!(low_player_id: [ @owner.id, player.id ].min, high_player_id: [ @owner.id, player.id ].max)
  end

  test "a visitor reads the game set goals in number order between SUCCÈS and SETS, without bookmark nor custom set" do
    aim_at_mixed_sets

    get brother_path(locale: :fr, token: @owner.token)

    assert_response :success
    assert_select "section[aria-labelledby=profile-achievements-heading] + section.profile-section[aria-labelledby=profile-goals-heading] + " \
      "section[aria-labelledby=profile-sets-heading]"
    assert_select "h2#profile-goals-heading.profile-section__title", "Objectifs"
    assert_equal [ brother_set_path(locale: :fr, token: @owner.token, kind: "theme", key: "roguelike"),
      brother_set_path(locale: :fr, token: @owner.token, kind: "studio", key: "valve") ], rows.map { it["href"] }
    assert_equal %w[goal-tone--1 goal-tone--2], rows.map { it["class"][/goal-tone--\d/] }
    assert rows.all? { it.classes.include?("goal-row--no-bookmark") }

    theme = rows.first
    assert_equal "Roguelike, thème, 1 carte sur 5, plus que 2 pour Novice", theme.at_css(".visually-hidden").text
    assert_equal [ "Roguelike", "Thème", "1/5", "Plus que 2 pour Novice", "Album" ],
      [ ".goal-row__name b", ".goal-row__kind", ".goal-row__count", ".goal-row__next", ".goal-row__album" ].map { theme.at_css(it).text.squish }
    assert_equal [ "novice" ], theme.css(".set-row__tick").map { it["class"][/--(\w+)/, 1] }
    theme.element_children.reject { it.classes.include?("visually-hidden") }.each { assert_equal "true", it["aria-hidden"], it.to_html }

    assert_select ".goal-bookmark, #goals, .goals__count, .goals__free", false
    assert_not_includes response.body, "Mes favoris"
    assert_select "[style]", false
  end

  test "with goals on custom sets alone, or none, the profile has no OBJECTIFS" do
    get brother_path(locale: :fr, token: @owner.token)
    assert_select "#profile-goals-heading, .goal-row", false

    add(custom_set: create_custom_set(@owner).token)
    get brother_path(locale: :fr, token: @owner.token)

    assert_response :success
    assert_select "#profile-goals-heading, .goal-row", false
    assert_not_includes response.body, "Mes favoris"
  end

  test "a private owner's goals reach no one; a friends-only owner's reach a friend, not a stranger" do
    aim_at_mixed_sets
    stranger = Accounts::Player.create!(steam_id: "76561197960390111")
    friend = Accounts::Player.create!(steam_id: "76561197960390112")
    befriend(friend)

    @owner.update!(visibility: "private")
    get brother_path(locale: :fr, token: @owner.token)
    assert_response :not_found
    assert_select ".goal-row", false
    sign_in(friend)
    get brother_path(locale: :fr, token: @owner.token)
    assert_response :not_found
    assert_select ".goal-row", false

    @owner.update!(visibility: "friends_only")
    get brother_path(locale: :fr, token: @owner.token)
    assert_response :success
    assert_equal 2, rows.size
    delete session_path(locale: :fr)

    sign_in(stranger)
    get brother_path(locale: :fr, token: @owner.token)
    assert_response :not_found
    assert_select ".goal-row", false
  end

  test "with no published season, the profile shows the no-season line and no goal" do
    aim_at_mixed_sets
    catalog_seasons(:one).update_columns(status: "draft", published_at: nil)

    get brother_path(locale: :fr, token: @owner.token)

    assert_response :success
    assert_select ".profile__no-season"
    assert_select "#profile-goals-heading, .goal-row", false
  end
end

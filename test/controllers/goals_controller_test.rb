require "test_helper"
require_relative "../support/counting_rate_limit"
require_relative "../support/custom_sets"
require_relative "../support/game_sets"
require_relative "../support/steam_sign_in"

# Marking and unmarking goals from an album: a Turbo Stream answer redraws
# the goal control alone, a refusal at five goals is written under it, and
# a plain form goes back to the album.
class GoalsControllerTest < ActionDispatch::IntegrationTest
  include CountingRateLimit
  include CustomSets
  include GameSets
  include SteamSignIn

  STREAM = { "Accept" => "text/vnd.turbo-stream.html, text/html" }.freeze

  setup do
    @player = accounts_players(:player)
  end

  def theme(key) = insert_set(unheld_cards(3), { complete: 3 }, key:, params: { "theme" => key })

  def goals = Game::Goal.where(player_id: @player.id).order(:position).pluck(:position, :set_kind, :set_key, :custom_set_id)

  def writes = Game::Goal.count + Rails.configuration.event_store.read.count

  def control = Nokogiri::HTML5.fragment(css_select("turbo-stream template").sole.inner_html)

  test "marking a game set redraws its control as goal 1, by morph; unmarking redraws it unmarked" do
    sign_in(@player)

    post library_goals_path(locale: :fr), params: { kind: "studio", key: "valve" }, headers: STREAM

    assert_response :ok
    assert_equal [ [ 1, "studio", "valve", nil ] ], goals
    assert_select "turbo-stream[action=replace][target=set-album-goal][method=morph]"
    button = control.at_css("#set-album-goal.goal-control--set.goal-tone--1 form[action='/fr/library/goals'] button.goal-button")
    assert_equal "Objectif 1, Valve. Retirer des objectifs", button["aria-label"]
    assert_equal "1Objectif 1 · Retirer", button.text.squish
    assert_equal [ "delete", "studio", "valve" ], %w[_method kind key].map { control.at_css("input[name=#{it}]")["value"] }
    assert_equal "", control.at_css("p.goal-control__refusal[role=status]").text

    delete library_goals_path(locale: :fr), params: { kind: "studio", key: "valve" }, headers: STREAM

    assert_empty goals
    assert_equal "Marquer comme objectif", control.at_css("#set-album-goal:not(.goal-control--set) button.goal-button").text.squish
  end

  test "a custom set is marked by its token" do
    custom_set = create_custom_set(@player)
    sign_in(@player)

    post library_goals_path(locale: :en), params: { custom_set: custom_set.token }, headers: STREAM

    assert_equal [ [ 1, nil, nil, custom_set.id ] ], goals
    assert_equal "Goal 1, Mes favoris. Remove from goals", control.at_css("button.goal-button")["aria-label"]
    assert_equal custom_set.token, control.at_css("input[name=custom_set]")["value"]
  end

  test "a sixth goal writes the refusal under the button with the way to the goals, and nothing else" do
    %w[a1 a2 a3 a4 a5 a6].each { theme(it) }
    %w[a1 a2 a3 a4 a5].each { Game::AddGoal.new.call(player: @player, kind: "theme", key: it).value! }
    sign_in(@player)

    assert_no_difference -> { writes } do
      post library_goals_path(locale: :fr), params: { kind: "theme", key: "a6" }, headers: STREAM
    end

    assert_response :ok
    refusal = control.at_css("p.goal-control__refusal[role=status]")
    assert_equal "5 objectifs au plus · Retirez un objectif pour en ajouter un autre.Voir mes objectifs", refusal.text.squish
    assert_equal "/fr/library#goals", refusal.at_css("a.goal-control__link")["href"]
    assert_equal "Marquer comme objectif", control.at_css("button.goal-button").text.squish
  end

  test "another refusal is a toast" do
    sign_in(@player)

    post library_goals_path(locale: :en), params: { kind: "theme", key: "pirates" }, headers: STREAM

    assert_response :unprocessable_content
    assert_select "turbo-stream[action=append][target=toasts]"
    assert_includes response.body, I18n.t("errors.game.goal_set_not_found", locale: :en)
  end

  test "without Turbo, the form goes back to the album, with the refusal or the alert" do
    custom_set = create_custom_set(@player)
    %w[a1 a2 a3 a4 a5].each { theme(it) }
    sign_in(@player)

    post library_goals_path(locale: :fr), params: { kind: "studio", key: "valve" }
    assert_redirected_to "/fr/library/studio/valve"
    follow_redirect!
    assert_select "#set-album-goal.goal-control--set button.goal-button[aria-label='Objectif 1, Valve. Retirer des objectifs']"

    %w[a1 a2 a3 a4].each { post library_goals_path(locale: :fr), params: { kind: "theme", key: it } }
    post library_goals_path(locale: :fr), params: { custom_set: custom_set.token }
    assert_redirected_to "/fr/library/custom-sets/#{custom_set.token}"
    follow_redirect!
    assert_select "#set-album-goal p.goal-control__refusal", /5 objectifs au plus/

    post library_goals_path(locale: :fr), params: { custom_set: "nope" }
    assert_redirected_to "/fr/library"
    assert_equal I18n.t("errors.game.custom_set_not_found", locale: :fr), flash[:alert]
  end

  test "a visitor is sent to the landing and nothing is written" do
    assert_no_difference -> { writes } do
      post library_goals_path(locale: :en), params: { kind: "studio", key: "valve" }
      delete library_goals_path(locale: :en), params: { kind: "studio", key: "valve" }
    end
    assert_redirected_to home_path(locale: :en)
  end

  test "the control names the goal by its set alone, never by a database id" do
    custom_set = create_custom_set(@player)
    sign_in(@player)

    post library_goals_path(locale: :en), params: { custom_set: custom_set.token }, headers: STREAM

    form = control.at_css("form")
    assert_equal "/en/library/goals", form["action"]
    assert_equal({ "_method" => "delete", "custom_set" => custom_set.token }, form.css("input:not([name=authenticity_token])").to_h { [ it["name"], it["value"] ] })
    assert_equal [ "set-album-goal" ], control.css("[id]").map { it["id"] }
  end

  test "goal changes are limited to twenty a minute" do
    sign_in(@player)

    with_counting_rate_limit(GoalsController) do
      10.times do
        post library_goals_path(locale: :fr), params: { kind: "studio", key: "valve" }
        delete library_goals_path(locale: :fr), params: { kind: "studio", key: "valve" }
      end
      assert_no_difference -> { writes } do
        post library_goals_path(locale: :fr), params: { kind: "studio", key: "valve" }
      end
      assert_redirected_to "/fr/library/studio/valve"
      assert_equal I18n.t("goals.throttled", locale: :fr), flash[:alert]
    end
  end
end

require "application_system_test_case"
require_relative "../support/custom_sets"
require_relative "../support/game_packs"
require_relative "../support/game_sets"
require_relative "../support/steam_sign_in"

# A player marks sets as goals from their albums, follows them under
# OBJECTIFS on the collection, is refused a sixth, and sees a goal leave
# with a toast once a capsule completes its set, after the cards are shown.
class GoalsTest < ApplicationSystemTestCase
  include CustomSets
  include GamePacks
  include GameSets
  include SteamSignIn

  setup do
    @player = accounts_players(:player)
  end

  def sign_in(player)
    mock_steam_sign_in(player.steam_id)
    visit home_path(locale: :en)
    click_steam_sign_in
    assert_signed_in
  end

  def theme(key) = insert_set(unheld_cards(3), { complete: 3 }, key:, params: { "theme" => key })

  def goal_button = find("#set-album-goal .goal-button")

  def assert_focus_on_goal_button
    eventually("the focus should stay on the goal button") do
      page.evaluate_script("document.activeElement?.matches('#set-album-goal .goal-button') === true")
    end
  end

  def press_goal_button(text)
    goal_button.click
    assert_selector "#set-album-goal .goal-button", text:
    assert_focus_on_goal_button
  end

  test "a player marks a game set and a custom set from their albums, follows them under OBJECTIFS, and a removed number is taken again" do
    theme("roguelike")
    theme("horror")
    custom_set = create_custom_set(@player)
    sign_in(@player)

    visit library_set_path(locale: :en, kind: "theme", key: "roguelike")
    press_goal_button("GOAL 1 · REMOVE")
    assert_equal "Goal 1, Roguelike. Remove from goals", goal_button["aria-label"]
    assert_selector ".set-album__header #set-album-goal.goal-control--set.goal-tone--1"

    visit custom_set_path(locale: :en, token: custom_set.token)
    press_goal_button("GOAL 2 · REMOVE")

    visit library_path(locale: :en)
    within("#goals") do
      assert_selector ".goals__count", text: "2 / 5"
      assert_selector ".goal-row", count: 2
      names = all(".goal-row .goal-row__name b").map(&:text)
      assert_equal [ "Roguelike", "Mes favoris" ], names
      assert_selector ".goal-row", text: /0\/3/, count: 2
      assert_selector ".goal-row__next", text: /Only 3 more for/i, count: 2
      assert_selector ".goals__free", text: "3 free goals · mark a set from its album"
    end

    visit library_set_path(locale: :en, kind: "theme", key: "roguelike")
    press_goal_button("MARK AS GOAL")
    visit library_set_path(locale: :en, kind: "theme", key: "horror")
    press_goal_button("GOAL 1 · REMOVE")
    visit custom_set_path(locale: :en, token: custom_set.token)
    assert_selector "#set-album-goal .goal-button", text: "GOAL 2 · REMOVE"
  end

  test "a sixth goal is refused under the button, with the way to OBJECTIFS; a search hides OBJECTIFS like MES SETS" do
    %w[a1 a2 a3 a4 a5 a6].each { theme(it) }
    %w[a1 a2 a3 a4 a5].each { Game::AddGoal.new.call(player: @player, kind: "theme", key: it).value! }
    sign_in(@player)

    visit library_set_path(locale: :en, kind: "theme", key: "a6")
    goal_button.click
    within("#set-album-goal .goal-control__refusal[role=status]") do
      assert_text "5 GOALS AT MOST · Remove a goal to add another one."
      assert_link "See my goals", href: "/en/library#goals"
    end
    assert_focus_on_goal_button
    assert_selector "#set-album-goal .goal-button", text: "MARK AS GOAL"
    assert_equal 5, Game::Goal.where(player_id: @player.id).count

    click_on "See my goals"
    assert_selector "#goals .goal-row", count: 5
    assert_no_selector "#goals .goals__free"

    fill_in "set-search-field", with: "a1"
    assert_selector ".set-results"
    assert_no_selector "#goals"
    assert_no_selector ".custom-sets"
    fill_in "set-search-field", with: ""
    assert_selector "#goals"
  end

  test "a capsule completing a goal's set toasts OBJECTIF ATTEINT after the cards are revealed, and the goal leaves" do
    Game::AddGoal.new.call(player: @player, kind: "studio", key: "valve").value!
    create_pack(@player, cards: %i[common_card_one uncommon_card_one rare_card_one portal_one common_card_one].map { catalog_card_seasons(it).id })
    sign_in(@player)
    page.driver.browser.execute_cdp("Emulation.setEmulatedMedia", features: [ { name: "prefers-reduced-motion", value: "reduce" } ])

    visit booster_path(locale: :en)
    find(".booster-canister").click
    assert_selector ".booster-card[data-dealt]", count: 5, wait: 10
    assert_selector ".booster__state", text: /\AINVENTORY\z/
    (1..4).each do |position|
      find(".booster-card:nth-child(#{position}) .booster-card__hit").click
      assert_selector ".booster-card:nth-child(#{position})[data-revealed]"
    end
    assert_no_selector ".toast", text: /GOAL REACHED/i
    find(".booster-card:nth-child(5) .booster-card__hit").click

    assert_selector ".toast", text: /GOAL REACHED\s+Valve/i
    assert_selector ".booster__info .booster-celebration", text: /SET COMPLETE\s+VALVE/

    page.driver.browser.execute_cdp("Emulation.setEmulatedMedia", features: [ { name: "prefers-reduced-motion", value: "" } ])
    visit library_path(locale: :en)
    assert_selector "#goals .goals__count", text: "0 / 5"
    assert_no_selector "#goals .goal-row"
  end
end

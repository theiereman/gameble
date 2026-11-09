require "test_helper"
require_relative "../support/steam_sign_in"

class FortunePanelsControllerTest < ActionDispatch::IntegrationTest
  include SteamSignIn

  MONDAY = Time.utc(2026, 11, 2, 9)
  THURSDAY = Time.utc(2026, 11, 5, 9)

  setup { @player = accounts_players(:player) }

  def other(number, **attributes) = Accounts::Player.create!({ steam_id: (76561197960700000 + number).to_s, persona_name: "Player#{number}" }.merge(attributes))

  def luck(player, z_score, week_start:)
    Game::Fortune.insert_all!([ { player_id: player.id, week_start:, regular_packs: 1, actual_points: (z_score * 100).round,
      expected_points: 0, variance: 10_000, created_at: MONDAY, updated_at: MONDAY } ])
  end

  def this_week(time) = Game::WeeklyGoal.week_start(time)

  test "a visitor has no panel" do
    get fortune_panel_path(locale: :en)

    assert_response :redirect
  end

  test "the Week tab: the player's index, one marker in the gauge, the top 3 and the link outside the frame" do
    4.times { |number| luck(other(number), 3.0 - number, week_start: this_week(THURSDAY)) }
    luck(@player, -1.5, week_start: this_week(THURSDAY))
    sign_in(@player)

    travel_to(THURSDAY) { get fortune_panel_path(locale: :fr) }

    assert_response :success
    assert_select "turbo-frame#fortune-panel[target=_top]" do
      assert_select "h2", "Le Chattomètre"
      assert_select "[role=group] button[aria-pressed=true]", "Semaine"
      assert_select "[role=group] button[aria-pressed=false]", "Total"
      assert_select ".fortune-panel__headline .fortune-index__value", /\A-\d+\z/
      assert_select ".fortune-gauge__column", 49
      assert_select ".fortune-gauge__marker", 1
      assert_select ".fortune-gauge__you", "VOUS"
      assert_select ".fortune-panel__row", 3
      assert_select ".fortune-panel__row .fortune-panel__privileged", 1
      assert_select ".fortune-gauge__zone-label", "PRIVILÉGIÉS"
      assert_select ".fortune-gauge .visually-hidden", /5 joueurs classés.*Vous êtes à -\d+, rang 5 sur 5\./
      assert_select ".panel .fortune-panel__more", false
      assert_select ".fortune-panel__more a.button--link[href=?]", fortune_register_path(locale: :fr), "Voir tout le classement"
    end
    assert_select "[style]", false
  end

  test "the Total tab switches everything to all time" do
    luck(@player, 2.0, week_start: nil)
    sign_in(@player)

    travel_to(THURSDAY) { get fortune_panel_path(locale: :en, tab: "all_time") }

    assert_select "button[aria-pressed=true]", "Total"
    assert_select ".fortune-gauge__marker", 1
    assert_select ".fortune-panel__more a[href=?]", fortune_register_path(locale: :en, period: "all_time")
  end

  test "from Monday to Wednesday the Week tab reads last week's verdict, naming the first public player" do
    winner = other(1)
    last_week = this_week(MONDAY) - 7
    luck(other(2, persona_name: "Hidden", visibility: :friends_only), 5.0, week_start: last_week)
    luck(winner, 2.0, week_start: last_week)
    luck(@player, -1.0, week_start: last_week)
    sign_in(@player)

    travel_to(MONDAY) { get fortune_panel_path(locale: :fr) }

    assert_select "h2", "Le Chattomètre"
    assert_select ".fortune-panel__period", "Semaine passée"
    assert_select ".fortune-panel__winner", "Player1"
    assert_select ".fortune-panel__verdict svg.fortune-panel__avatar"
    assert_select ".fortune-gauge__column--privileged", false
    assert_select ".fortune-gauge__marker", 1
    assert_select ".fortune-panel__more a[href=?]", fortune_register_path(locale: :fr, period: "last_week")
    assert_select ".fortune-panel__name", "Membre discret"
  end

  test "a player with no standing sees the curve without a marker, and a private player's index stays theirs" do
    luck(other(1), 1.0, week_start: this_week(THURSDAY))
    sign_in(@player)

    travel_to(THURSDAY) { get fortune_panel_path(locale: :en) }
    assert_select ".fortune-gauge__marker", false
    assert_select ".fortune-panel__headline", /No capsule opened/

    @player.update!(visibility: :private)
    luck(@player, 1.0, week_start: this_week(THURSDAY))

    travel_to(THURSDAY) { get fortune_panel_path(locale: :en) }
    assert_select ".fortune-gauge__marker", false
    assert_select ".fortune-panel__headline .fortune-index__value"
    assert_select ".fortune-panel__row", 1
  end

  test "the hub carries the panel, its feed block kept for the phone" do
    sign_in(@player)

    get home_path(locale: :en)

    assert_select ".hub__aside section.fortune-panel[data-controller=fortune-panel] turbo-frame#fortune-panel"
    assert_select ".hub__aside .hub__phone-feed .live-strip"
  end
end

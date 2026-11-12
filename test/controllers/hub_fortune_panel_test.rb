require "test_helper"
require_relative "../support/steam_sign_in"

class HubFortunePanelTest < ActionDispatch::IntegrationTest
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

  test "the hub panel reads this week only: the player's index, one marker in the gauge, the top 3 and the link to the register" do
    4.times { |number| luck(other(number), 3.0 - number, week_start: this_week(THURSDAY)) }
    luck(@player, -1.5, week_start: this_week(THURSDAY))
    luck(@player, 4.0, week_start: nil)
    sign_in(@player)

    travel_to(THURSDAY) { get home_path(locale: :fr) }

    assert_response :success
    assert_select ".hub__aside section.fortune-panel" do
      assert_select ".panel.hub-linked h2 a.hub-linked__link[href=?]", fortune_register_path(locale: :fr), "Le Chattomètre"
      assert_select "a", 1
      assert_select "button, [role=group], turbo-frame", false
      assert_select ".fortune-panel__headline .fortune-index__value", /\A-\d+\z/
      assert_select ".fortune-gauge__column", 49
      assert_select ".fortune-gauge__marker", 1
      assert_select ".fortune-gauge__you", "VOUS"
      assert_select ".fortune-panel__row", 3
      assert_select ".fortune-panel__row .fortune-panel__privileged", 1
      assert_select ".fortune-gauge__zone-label", "PRIVILÉGIÉS"
      assert_select ".fortune-gauge .visually-hidden", /5 joueurs classés.*Vous êtes à -\d+, rang 5 sur 5\./
    end
    assert_select ".hub__aside .hub__phone-feed .live-strip"
  end

  test "on Monday the panel shows only this week's board, never last week's winner" do
    last_week = this_week(MONDAY) - 7
    luck(other(1), 2.0, week_start: last_week)
    luck(@player, -1.0, week_start: last_week)
    luck(other(3, persona_name: "Hidden", visibility: :friends_only), 1.0, week_start: this_week(MONDAY))
    sign_in(@player)

    travel_to(MONDAY) { get home_path(locale: :fr) }

    assert_select ".fortune-panel" do
      assert_select ".fortune-panel__headline", /Aucune capsule ouverte cette semaine/
      assert_no_match(/Player1|Semaine passée/, css_select(".fortune-panel").text)
      assert_select ".fortune-panel__row", 1
      assert_select ".fortune-panel__name", "Membre discret"
      assert_select "a.hub-linked__link[href=?]", fortune_register_path(locale: :fr)
    end
  end

  test "a player with no standing sees the curve without a marker, and a private player's index stays theirs" do
    luck(other(1), 1.0, week_start: this_week(THURSDAY))
    sign_in(@player)

    travel_to(THURSDAY) { get home_path(locale: :en) }
    assert_select ".fortune-gauge__marker", false
    assert_select ".fortune-panel__headline", /No capsule opened this week/

    @player.update!(visibility: :private)
    luck(@player, 1.0, week_start: this_week(THURSDAY))

    travel_to(THURSDAY) { get home_path(locale: :en) }
    assert_select ".fortune-gauge__marker", false
    assert_select ".fortune-panel__headline .fortune-index__value"
    assert_select ".fortune-panel__row", 1
  end
end

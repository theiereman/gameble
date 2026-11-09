require "test_helper"

class Game::FortuneVerdictTest < ActiveSupport::TestCase
  MONDAY = Time.utc(2026, 11, 2)

  def player(number, **attributes) = Accounts::Player.create!(steam_id: (76561197960600000 + number).to_s, **attributes)

  def luck(player, z_score)
    Game::Fortune.insert_all!([ { player_id: player.id, week_start: MONDAY.to_date - 7, regular_packs: 1, actual_points: (z_score * 100).round,
      expected_points: 0, variance: 10_000, created_at: MONDAY, updated_at: MONDAY } ])
  end

  test "the verdict is open from Monday midnight UTC to the end of Wednesday" do
    assert Game::FortuneVerdict.open?(MONDAY)
    assert Game::FortuneVerdict.open?(MONDAY + 3.days - 1.second)
    assert_not Game::FortuneVerdict.open?(MONDAY + 3.days)
    assert_not Game::FortuneVerdict.open?(MONDAY - 1.second)
  end

  test "it names last week's first public player, never a friends-only or private one" do
    public_player = player(1)
    luck(player(2, visibility: :friends_only), 5.0)
    luck(player(3, visibility: :private), 4.0)
    luck(public_player, 1.0)

    verdict = Game::FortuneVerdict.call(now: MONDAY)

    assert_equal public_player, verdict.player
    assert_equal Game::FortuneIndex.of(1.0), verdict.index
  end

  test "there is no verdict outside its days, or without a public player" do
    luck(player(1, visibility: :friends_only), 5.0)

    assert_nil Game::FortuneVerdict.call(now: MONDAY)
    luck(player(2), 1.0)
    assert_nil Game::FortuneVerdict.call(now: MONDAY + 4.days)
  end
end

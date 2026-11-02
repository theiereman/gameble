require "test_helper"
require_relative "../support/steam_sign_in"

class AchievementClaimsControllerTest < ActionDispatch::IntegrationTest
  include SteamSignIn

  setup do
    @player = accounts_players(:player)
    @other = accounts_players(:moderator)
  end

  def unlock(key, player: @player, claimed: false)
    Game::AchievementUnlock.record(player.id, key, Time.current, claimed:)
  end

  test "the achievements screen shows a Claim button on an unclaimed reward only, and a GET writes nothing" do
    unlock("boosters_100")
    unlock("first_legendary", claimed: true)
    sign_in(@player)

    assert_no_difference -> { Game::AchievementUnlock.claimed.count } do
      get achievements_path(locale: :en)
    end

    assert_select "form[action=?]", claim_achievement_path(locale: :en, achievement: "boosters_100")
    assert_select "form[action=?]", claim_achievement_path(locale: :en, achievement: "first_legendary"), count: 0
  end

  test "the menu badge counts the unclaimed rewards" do
    unlock("boosters_100")
    unlock("first_legendary")
    sign_in(@player)

    get more_path(locale: :en)

    assert_select "#plus-achievements-badge .menu-item__badge", "2"
  end

  test "claiming redirects to the achievements and marks the achievement claimed" do
    unlock("boosters_100")
    sign_in(@player)

    post claim_achievement_path(locale: :en, achievement: "boosters_100")

    assert_redirected_to achievements_path(locale: :en)
    assert_equal 0, Game::UnclaimedAchievements.count(@player)
  end

  test "claiming another player's achievement or one not earned is refused" do
    unlock("boosters_100", player: @other)
    sign_in(@player)

    post claim_achievement_path(locale: :en, achievement: "boosters_100")

    assert_redirected_to achievements_path(locale: :en)
    assert_equal 1, Game::UnclaimedAchievements.count(@other)
    assert_not_nil flash[:alert]
  end

  test "a visitor may not claim" do
    post claim_achievement_path(locale: :en, achievement: "boosters_100")

    assert_response :redirect
    assert_equal 0, Game::AchievementUnlock.claimed.where(achievement: "boosters_100").count
  end
end

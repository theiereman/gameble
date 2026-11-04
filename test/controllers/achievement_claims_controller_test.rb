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

    get me_path(locale: :en)

    assert_select "#plus-achievements-badge .menu-item__badge", "2"
  end

  test "claiming redirects to the achievements and marks the achievement claimed" do
    unlock("boosters_100")
    sign_in(@player)

    post claim_achievement_path(locale: :en, achievement: "boosters_100")

    assert_redirected_to achievements_path(locale: :en)
    assert_equal 0, Game::UnclaimedAchievements.count(@player)
  end

  test "claiming in a Turbo Stream replaces the row, updates both menu badges and adds a toast, without a redirect" do
    unlock("boosters_100")
    unlock("first_legendary")
    sign_in(@player)

    post claim_achievement_path(locale: :en, achievement: "boosters_100"), as: :turbo_stream

    assert_response :success
    assert_equal Mime[:turbo_stream], response.media_type
    assert_equal 1, Game::UnclaimedAchievements.count(@player)
    assert_select "turbo-stream[action=replace][target=achievement-boosters_100] template li#achievement-boosters_100" do
      assert_select "form.achievement__claim-form", 0
    end
    assert_select "turbo-stream[action=gameble-focus][target=achievement-boosters_100]"
    assert_select "turbo-stream[action=update][target=menu-achievements-badge] .menu-item__badge", "1"
    assert_select "turbo-stream[action=update][target=plus-achievements-badge] .menu-item__badge", "1"
    assert_select "turbo-stream[action=update][target=tab-me-badge]"
    assert_select "turbo-stream[action=append][target=toasts]", text: /Reward claimed/
  end

  test "claiming the last reward in a Turbo Stream empties the menu badges" do
    unlock("boosters_100")
    sign_in(@player)

    post claim_achievement_path(locale: :en, achievement: "boosters_100"), as: :turbo_stream

    assert_select "turbo-stream[action=update][target=menu-achievements-badge] .menu-item__badge", 0
    assert_select "turbo-stream[action=update][target=plus-achievements-badge] .menu-item__badge", 0
  end

  test "a refused claim in a Turbo Stream answers an alert toast and claims nothing" do
    unlock("boosters_100", player: @other)
    sign_in(@player)

    post claim_achievement_path(locale: :en, achievement: "boosters_100"), as: :turbo_stream

    assert_response :success
    assert_equal 1, Game::UnclaimedAchievements.count(@other)
    assert_select "turbo-stream[action=append][target=toasts] .toast--alert"
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

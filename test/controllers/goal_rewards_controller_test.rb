require "test_helper"
require_relative "../support/counting_rate_limit"
require_relative "../support/game_packs"
require_relative "../support/steam_sign_in"

# Claiming a weekly goal reward from the hub's goal panel: end to end, in
# Turbo Stream and in HTML, and every refusal.
class GoalRewardsControllerTest < ActionDispatch::IntegrationTest
  include CountingRateLimit
  include GamePacks
  include SteamSignIn

  setup do
    @player = accounts_players(:player)
    @week = Game::WeeklyGoal.week_start(Time.current) - 7
    Game::WeeklyGoal.create!(week_start: @week, total: 200, target: 200)
    Game::WeeklyContribution.create!(player_id: @player.id, week_start: @week, openings: 1)
    Game::GrantGoalReward.new.call(player: @player, week_start: @week).value!
  end

  def claim_path(week = @week, locale: :en) = goal_reward_path(week: week.to_s, locale:)

  def reserve_badge(kind = :standard)
    css_select("#hub-menu-booster .menu-item__badge--#{kind}").sole.text
  end

  def reward_pack_count = Game::Pack.where(player_id: @player.id).reward.count

  test "a player claims the reward from the hub: one more pack, the slot collected, and it stays so on reload" do
    Game::FillBank.new.call(player: @player).value!
    Game::OpenPack.new.call(player: @player).value!
    sign_in(@player)

    get home_path(locale: :en)
    assert_equal "9", reserve_badge
    assert_select "#goal-reward form[action='/en/goal-rewards/#{@week.iso8601}'] button", "Collect"

    post claim_path

    assert_redirected_to home_path(locale: :en)
    assert_response :see_other
    assert_equal "Management thanks you for your contribution. A rare capsule has been added to your reserve.", flash[:notice]
    follow_redirect!
    assert_equal "9", reserve_badge
    assert_equal "1", reserve_badge(:special)
    assert_select "#toasts .toast--notice .toast__title", "Mission accomplished"
    assert_select "#goal-reward .hub-goal__claim-state", "Collected"

    get home_path(locale: :en)
    assert_select "#goal-reward .hub-goal__claim-state", "Collected"

    post claim_path
    assert_equal "You have already collected this rare capsule.", flash[:alert]
    assert_nil flash[:toast_title]
    assert_equal 1, reward_pack_count
  end

  def stream_post(week = @week, locale: :en)
    post claim_path(week, locale:), as: :turbo_stream
    assert_response :success
    assert_equal Mime[:turbo_stream], response.media_type
  end

  test "from Turbo, the claim answers in Turbo Stream: the slot collected, the chip, menu 01, the showcase's action and a titled toast" do
    sign_in(@player)

    assert_difference -> { reward_pack_count }, 1 do
      stream_post
    end

    assert_select "turbo-stream[action=replace][target=goal-reward] template #goal-reward.hub-goal__claim--collected .hub-goal__claim-state", "Collected"
    assert_select "turbo-stream[action=replace][target=packs-chip] template div#packs-chip .packs-chip__special-count", "1"
    assert_select "turbo-stream[action=replace][target=hub-menu-booster] template li#hub-menu-booster .menu-item__badge--special", "1"
    assert_select "turbo-stream[action=replace][target=hub-menu-booster] template li#hub-menu-booster .menu-item__badge--standard", false
    assert_select "turbo-stream[action=replace][target=hub-showcase-actions] template #hub-showcase-actions"
    assert_select "turbo-stream[target=daily-booster]", false
    assert_select "turbo-stream[action=append][target=toasts] template .toast.toast--notice .toast__message",
      "Management thanks you for your contribution. A rare capsule has been added to your reserve."
    assert_select "turbo-stream[action=append][target=toasts] template .toast.toast--notice .toast__title", "Mission accomplished"
  end

  test "from Turbo, a claim at a full standard reserve succeeds: the slot collected, the special count shown, the daily panel untouched" do
    Game::FillBank.new.call(player: @player).value!
    sign_in(@player)

    stream_post

    assert_select "turbo-stream[action=replace][target=goal-reward] template #goal-reward.hub-goal__claim--collected"
    assert_select "turbo-stream[target=daily-booster]", false
    assert_select "turbo-stream[action=replace][target=packs-chip] template div#packs-chip .packs-chip__special-count", "1"
    assert_select "turbo-stream[action=append][target=toasts] template .toast--notice .toast__message",
      "Management thanks you for your contribution. A rare capsule has been added to your reserve."
    assert_equal 1, reward_pack_count
  end

  test "with a full standard reserve an HTML claim succeeds in the page's language and the standard reserve is unchanged" do
    Game::FillBank.new.call(player: @player).value!
    sign_in(@player)

    post claim_path(locale: :fr)
    assert_redirected_to home_path(locale: :fr)
    assert_equal "La Direction vous remercie pour votre participation. Une capsule rare a rejoint votre réserve.", flash[:notice]
    assert_equal "Mission accomplie", flash[:toast_title]
    assert_equal 1, reward_pack_count
    assert_equal 10, Game::Reserve.counts(@player.id).standard
  end

  test "a week not earned or a date that does not parse is refused as not earned; a malformed week is no route" do
    sign_in(@player)

    post claim_path(@week - 7)
    assert_equal "No rare capsule waits for you for that week.", flash[:alert]

    post claim_path("2026-13-45", locale: :fr)
    assert_equal "Aucune capsule rare ne vous attend pour cette semaine.", flash[:alert]

    post "/en/goal-rewards/#{@week.iso8601}x"
    assert_response :not_found
    assert_equal 0, reward_pack_count
  end

  test "without a published season the claim is refused and the reward waits" do
    catalog_seasons(:one).update_columns(status: "draft", published_at: nil)
    Game::DrawPool.reset!
    sign_in(@player)

    post claim_path(locale: :fr)

    assert_equal "Aucune saison de cartes n'est ouverte. Revenez plus tard pour votre capsule rare.", flash[:alert]
    assert_equal [ nil ], Game::GoalReward.where(player_id: @player.id).pluck(:pack_id)
  end

  test "a visitor's claim is redirected with the sign-in message, nothing written" do
    assert_no_difference -> { Game::Pack.count } do
      post claim_path
    end
    assert_redirected_to home_path(locale: :en)
    assert_nil flash[:alert]

    post claim_path, as: :turbo_stream
    assert_redirected_to home_path(locale: :en)
    assert_equal 0, reward_pack_count
  end

  test "more than 5 claims a minute by one player are sent back with their own message" do
    sign_in(@player)
    with_counting_rate_limit(GoalRewardsController) do
      5.times do
        post claim_path
        assert_response :see_other
        assert_not_equal I18n.t("goal_rewards.create.throttled", locale: :en), flash[:alert]
      end

      post claim_path
    end

    assert_redirected_to home_path(locale: :en)
    assert_equal I18n.t("goal_rewards.create.throttled", locale: :en), flash[:alert]
  end
end

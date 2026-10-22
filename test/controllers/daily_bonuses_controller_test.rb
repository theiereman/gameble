require "test_helper"
require_relative "../support/counting_rate_limit"
require_relative "../support/game_packs"
require_relative "../support/steam_sign_in"

# The hub's daily booster panel and its collection (CAP-16, R8): end to
# end, the result page of a bonus pack, and every refusal.
class DailyBonusesControllerTest < ActionDispatch::IntegrationTest
  include CountingRateLimit
  include GamePacks
  include SteamSignIn

  setup do
    @player = accounts_players(:player)
  end

  def reserve_badge
    css_select("#hub-menu-booster .menu-item__badge").sole.text
  end

  def panel
    css_select(".daily-booster")
  end

  test "a player collects the bonus from the hub: one more pack, the panel collected, refused again that day, back the next" do
    now = Time.utc(2026, 10, 2, 22, 0)
    travel_to(now) do
      Game::FillBank.new.call(player: @player).value!
      Game::OpenPack.new.call(player: @player).value!
    end
    sign_in(@player)

    travel_to(now) do
      get home_path(locale: :en)
      assert_equal "9", reserve_badge
      assert_select ".daily-booster h2", "Daily capsule"
      assert_select ".daily-booster form[action='/en/daily-bonus'][method=post] button", "Collect"

      post daily_bonus_path(locale: :en)

      assert_redirected_to home_path(locale: :en)
      assert_response :see_other
      assert_equal "A capsule joins your reserve. The next one will be ready on 2026-10-03 00:00 UTC.", flash[:notice]
      follow_redirect!
      assert_equal "10", reserve_badge
      assert_select ".daily-booster.daily-booster--collected .daily-booster__state", "Collected"
      assert_select ".daily-booster .daily-booster__clock", "02:00:00"
      assert_select ".daily-booster form, .daily-booster button", 0

      post daily_bonus_path(locale: :en)

      assert_redirected_to home_path(locale: :en)
      assert_equal "You have already collected today's capsule. The next one will be ready on 2026-10-03 00:00 UTC.", flash[:alert]
      assert_equal 1, Game::DailyBonusClaim.where(player_id: @player.id).count
    end

    travel_to(Time.utc(2026, 10, 3, 0, 0, 1)) do
      get home_path(locale: :en)
      assert_equal 1, panel.size
      # The next day's panel is no longer collected: with ten boosters in reserve, it is full.
      assert_select ".daily-booster.daily-booster--full .daily-booster__state", "Reserve full"
    end
  end

  def stream_post(**params)
    post daily_bonus_path(locale: :en), params:, as: :turbo_stream
    assert_response :success
    assert_equal Mime[:turbo_stream], response.media_type
  end

  test "from Turbo, the claim answers in Turbo Stream: the panel collected and marked for the arc, the chip, menu 01 and a toast" do
    now = Time.utc(2026, 10, 2, 22, 0)
    travel_to(now) do
      Game::FillBank.new.call(player: @player).value!
      Game::OpenPack.new.call(player: @player).value!
    end
    sign_in(@player)

    travel_to(now) do
      assert_difference -> { Game::DailyBonusClaim.count }, 1 do
        stream_post
      end

      assert_select "turbo-stream[action=replace][target=daily-booster] template" do
        assert_select ".daily-booster#daily-booster.daily-booster--collected[data-bonus-arc-collected]"
        assert_select ".daily-booster__state", "Collected"
        assert_select ".daily-booster__clock", "02:00:00"
        bank = JSON.parse(css_select("[data-bonus-arc-collected]").sole["data-bonus-arc-bank"])
        assert_equal({ "available" => 10, "reserveFull" => true, "nextAvailableAt" => "2026-10-02T22:10:00Z", "serverTime" => "2026-10-02T22:00:00Z" }, bank)
      end
      assert_select "turbo-stream[action=replace][target=packs-chip] template a#packs-chip .packs-chip__count", "10"
      assert_select "turbo-stream[action=replace][target=packs-chip] template .packs-chip__next--full", "Reserve full"
      assert_select "turbo-stream[action=replace][target=hub-menu-booster] template li#hub-menu-booster .menu-item__badge", "10"
      assert_select "turbo-stream[action=replace][target=hub-showcase-actions] template #hub-showcase-actions"
      assert_select "turbo-stream[action=append][target=toasts] template .toast.toast--notice .toast__message",
        "A capsule joins your reserve. The next one will be ready on 2026-10-03 00:00 UTC."
      assert_select "turbo-stream[action=append][target=toasts] template .toast__message time[datetime='2026-10-03T00:00:00Z'][data-controller=local-time]"
    end
  end

  test "from Turbo, a second claim the same day is refused in Turbo Stream: the countdown panel without the arc, an alert toast" do
    sign_in(@player)
    stream_post
    assert_equal 1, Game::DailyBonusClaim.count

    assert_no_difference -> { Game::Pack.count } do
      stream_post
    end

    assert_select "turbo-stream[action=replace][target=daily-booster] template .daily-booster--collected .daily-booster__clock"
    assert_select "[data-bonus-arc-collected]", false
    next_day = Game::BankSummary.next_bonus_at.utc
    assert_select "turbo-stream[action=append][target=toasts] template .toast.toast--alert .toast__message",
      I18n.t("errors.game.already_collected", locale: :en, time: next_day.strftime("%Y-%m-%d %H:%M UTC"))
    assert_select "turbo-stream[action=append][target=toasts] template .toast__message time[datetime='#{next_day.iso8601}']"
    assert_equal 1, Game::DailyBonusClaim.count
  end

  test "from Turbo, a claim at a full reserve is refused in Turbo Stream: the full panel in orange, nothing written" do
    Game::FillBank.new.call(player: @player).value!
    sign_in(@player)

    assert_no_difference -> { Game::Pack.count } do
      stream_post
    end

    assert_select "turbo-stream[action=replace][target=daily-booster] template .daily-booster--full" do
      assert_select ".daily-booster__state--full", "Reserve full"
      assert_select "button[disabled]", "Collect"
    end
    assert_select "[data-bonus-arc-collected]", false
    assert_select "turbo-stream[action=append][target=toasts] template .toast--alert .toast__message", I18n.t("errors.game.reserve_full", locale: :en)
    assert_equal 0, Game::DailyBonusClaim.count
  end

  def earn_goal_reward
    week = Game::WeeklyGoal.week_start(Time.current) - 7
    Game::WeeklyGoal.create!(week_start: week, total: 200, target: 200)
    Game::WeeklyContribution.create!(player_id: @player.id, week_start: week, openings: 1)
    Game::GrantGoalReward.new.call(player: @player, week_start: week).value!
  end

  test "from Turbo, a bonus that fills the reserve turns a waiting goal reward's claim slot full" do
    earn_goal_reward
    Game::FillBank.new.call(player: @player).value!
    Game::OpenPack.new.call(player: @player).value!
    sign_in(@player)

    get home_path(locale: :en)
    assert_select "#goal-reward.hub-goal__claim--ready"

    stream_post

    assert_select "turbo-stream[action=replace][target=goal-reward] template #goal-reward.hub-goal__claim--full" do
      assert_select "button[disabled]", "Collect"
      assert_select ".hub-goal__claim-text", "Open a capsule to collect your rare capsule."
    end
  end

  test "from Turbo, a bonus that leaves room in the reserve does not touch the goal reward's claim slot" do
    earn_goal_reward
    Game::FillBank.new.call(player: @player).value!
    2.times { Game::OpenPack.new.call(player: @player).value! }
    sign_in(@player)

    stream_post

    assert_select "turbo-stream[target=goal-reward]", false
  end

  test "from Turbo, a visitor's claim is refused with the sign-in message, nothing written" do
    assert_no_difference -> { Game::DailyBonusClaim.count } do
      post daily_bonus_path(locale: :en), as: :turbo_stream
    end

    assert_redirected_to home_path(locale: :en)
    assert_nil flash[:alert]
  end

  test "with a full reserve, the panel says so and disables its button, and a collection is refused; nothing written" do
    Game::FillBank.new.call(player: @player).value!
    sign_in(@player)

    get home_path(locale: :en)
    assert_select ".daily-booster h2", "Daily capsule"
    assert_select ".daily-booster .daily-booster__state", "Reserve full"
    assert_select ".daily-booster .daily-booster__text", "Open a capsule to collect today's."
    assert_select ".daily-booster button[disabled]", "Collect"
    assert_select ".daily-booster form", 0

    get home_path(locale: :fr)
    assert_select ".daily-booster .daily-booster__text", "Ouvrez une capsule pour récupérer celle du jour."

    assert_no_difference -> { Game::Pack.count } do
      post daily_bonus_path(locale: :fr)
    end

    assert_redirected_to home_path(locale: :fr)
    assert_equal I18n.t("errors.game.reserve_full", locale: :fr), flash[:alert]
    assert_equal 0, Game::DailyBonusClaim.count
  end

  test "the panel's copy in French" do
    sign_in(@player)

    get home_path(locale: :fr)

    assert_select ".daily-booster h2", "Capsule quotidienne"
    assert_select ".daily-booster .daily-booster__state", "Prête"
    assert_select ".daily-booster .daily-booster__text", "Une capsule offerte chaque jour. Elle rejoint votre réserve."
    assert_select ".daily-booster button", "Récupérer"
  end

  test "a visitor sees no panel, and a visitor's POST is refused with the sign-in message; nothing written" do
    get home_path(locale: :en)
    assert_empty panel

    assert_no_difference -> { Game::Pack.count } do
      assert_no_difference -> { Game::DailyBonusClaim.count } do
        post daily_bonus_path(locale: :en)
      end
    end

    assert_redirected_to home_path(locale: :en)
    assert_nil flash[:alert]
  end

  test "with no season published, no panel, and a collection is refused with its message" do
    catalog_seasons(:one).update_columns(status: "draft", published_at: nil)
    sign_in(@player)

    get home_path(locale: :fr)
    assert_empty panel

    post daily_bonus_path(locale: :fr)

    assert_redirected_to home_path(locale: :fr)
    assert_equal I18n.t("errors.game.no_season", locale: :fr), flash[:alert]
    assert_equal 0, Game::DailyBonusClaim.count
  end

  test "more than 5 collections a minute by one player are sent back with their own message" do
    sign_in(@player)
    with_counting_rate_limit(DailyBonusesController) do
      5.times do
        post daily_bonus_path(locale: :en)
        assert_response :see_other
        assert_not_equal I18n.t("daily_bonuses.create.throttled", locale: :en), flash[:alert]
      end

      post daily_bonus_path(locale: :en)
    end

    assert_redirected_to home_path(locale: :en)
    assert_equal I18n.t("daily_bonuses.create.throttled", locale: :en), flash[:alert]
  end

  test "an opened bonus pack's page is titled the daily bonus and shows its three cards" do
    sign_in(@player)
    post daily_bonus_path(locale: :en)
    bonus = Game::Pack.where(player_id: @player.id).bonus.sole
    bonus.update_columns(available_at: 1.year.ago)
    post packs_path(locale: :en)

    assert_redirected_to "/en/packs/#{bonus.token}"
    follow_redirect!
    assert_select "h1", "Your daily capsule"
    assert_select ".pack-result__card .card.card--m", 3

    get pack_path(bonus.token, locale: :fr)
    assert_select "h1", "Votre capsule du jour"
    assert_select ".pack-result__card .card.card--m", 3
  end
end

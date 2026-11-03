require "test_helper"
require_relative "../support/steam_sign_in"

class BellsControllerTest < ActionDispatch::IntegrationTest
  include SteamSignIn

  FRAME = "turbo-frame#bell-items[target=_top]".freeze

  setup do
    @hugo = accounts_players(:player)
    @max = accounts_players(:moderator)
    @eve = accounts_players(:administrator)
  end

  def get_bell(locale: :en)
    get bell_path(locale:), headers: { "Turbo-Frame" => "bell-items" }
  end

  def trade(from, to)
    low, high = [ from.id, to.id ].minmax
    Game::Trade.create!(low_player_id: low, high_player_id: high, proposer_id: from.id, recipient_id: to.id,
      proposed_at: 1.hour.ago, expires_at: 1.day.from_now)
  end

  def line_keys = css_select("#{FRAME} li.bell__line[data-bell-target=item]").map { it["data-bell-key"] }

  test "the frame holds a line per thing new, each a link to its target, keyed without any id, writing nothing" do
    waiting = trade(@max, @hugo)
    invitation = Game::Invitation.create!(sender_id: @eve.id, recipient_id: @hugo.id, status: "pending")
    Game::WeeklyGoal.create!(week_start: Game::WeeklyGoal.week_start(Time.current), total: 0, target: 1_500)
    sign_in(@hugo)

    assert_no_difference -> { Game::Trade.count + Game::Invitation.count + Game::DailyBonusClaim.count } do
      get_bell
    end

    assert_response :success
    today = Time.current.utc.to_date.iso8601
    week = Game::WeeklyGoal.week_start(Time.current).iso8601
    assert_equal [ "trade:#{waiting.token}:#{waiting.revision}", "invitation:#{invitation.token}", "daily:#{today}", "mission:#{week}" ], line_keys

    assert_select "#{FRAME} li[data-bell-path='/en/trades/#{waiting.token}'] a.bell__link[href='/en/trades/#{waiting.token}'][data-action='bell#follow']",
      text: /#{@max.persona_name} awaits your answer to a trade\.\s+Answer/
    assert_select "#{FRAME} li[data-bell-path='/en/friends'] a[href='/en/friends']", text: /#{@eve.persona_name} invites you to be friends\.\s+See/
    assert_select "#{FRAME} li#bell-daily[data-bell-lasting=true][data-bell-path='/en/booster'] a[href='/en/booster']", text: /Your daily capsule is ready\.\s+Collect/
    assert_select "#{FRAME} li[data-bell-lasting=false]", 3
    assert_select "#{FRAME} li[data-bell-path='/en/social'] a[href='/en/social#community-goal']",
      text: /This week's mission: open 1,500 capsules together\.\s+See/
    assert_select "#{FRAME} p.bell__empty[data-bell-target=empty][hidden]", "Nothing new for now."
  end

  test "an answered proposal is a line to its trade, keyed by token and closing time, in the request's locale" do
    low, high = [ @hugo.id, @max.id ].minmax
    answered = Game::Trade.create!(low_player_id: low, high_player_id: high, proposer_id: @hugo.id, recipient_id: @max.id, status: "declined",
      proposed_at: 2.hours.ago, expires_at: 1.day.from_now, closed_at: 1.hour.ago)
    sign_in(@hugo)

    assert_no_difference -> { Game::TradeView.count } do
      get_bell
    end

    assert_includes line_keys, "trade-update:#{answered.token}:#{answered.closed_at.utc.iso8601(6)}"
    assert_select "#{FRAME} li[data-bell-path='/en/trades/#{answered.token}']", text: /#{@max.persona_name} declined your trade\./

    get_bell(locale: :fr)
    assert_select "#{FRAME} li[data-bell-path='/fr/trades/#{answered.token}']", text: /#{@max.persona_name} a refusé votre échange\./
  end

  test "an unclaimed mission reward replaces the week's line, in the request's locale" do
    Game::GoalReward.create!(player_id: @hugo.id, week_start: Date.new(2026, 9, 28))
    sign_in(@hugo)

    get_bell(locale: :fr)

    assert_includes line_keys, "mission-reward:2026-09-28"
    assert_select "#{FRAME} li#bell-mission-reward[data-bell-lasting=true]"
    assert_select "#{FRAME} li[data-bell-path='/fr/social'] a[href='/fr/social#community-goal']",
      text: /La mission hebdo est accomplie ?\s?: une capsule rare vous attend\.\s+Récupérer/
  end

  test "once the week's mission is accomplished, its line says so" do
    Game::WeeklyGoal.create!(week_start: Game::WeeklyGoal.week_start(Time.current), total: 1_500, target: 1_500)
    sign_in(@hugo)

    get_bell

    assert_select "#{FRAME} li[data-bell-path='/en/social'][data-bell-lasting=false] a",
      text: /This week's mission is accomplished: 1,500 capsules opened together\.\s+See/
  end

  test "a visit outside a frame is sent home" do
    sign_in(@hugo)

    get bell_path(locale: :en)

    assert_redirected_to home_path(locale: :en)
  end

  test "a visitor is refused" do
    get_bell

    assert_redirected_to home_path(locale: :en)
    assert_select FRAME, false
  end
end

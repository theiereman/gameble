require "test_helper"
require_relative "../support/steam_sign_in"
require_relative "../support/holdings"

# The Social home: the trades in progress, waiting on the player first, the
# recent ended ones kept quiet, the friends with their presence, the
# community goal, a way to the feed, and Add a friend and New trade last.
class SocialPageTest < ActionDispatch::IntegrationTest
  include Holdings
  include SteamSignIn

  setup do
    @hugo = accounts_players(:player).tap { it.update!(persona_name: "Hugo") }
    @lea = accounts_players(:moderator).tap { it.update!(persona_name: "Lea") }
    @max = accounts_players(:administrator).tap { it.update!(persona_name: "Max") }
    @portal = catalog_card_seasons(:portal_one).id
    @soldier = catalog_card_seasons(:common_card_one).id
    @depths = catalog_card_seasons(:rare_card_one).id
  end

  def befriend(first, second)
    low, high = [ first.id, second.id ].minmax
    Game::Friendship.create!(low_player_id: low, high_player_id: high)
  end

  def trading_friends
    [ @lea, @max ].each { befriend(@hugo, it) }
    hold(@hugo, @portal, 3)
    hold(@hugo, @soldier, 1)
    hold(@lea, @depths, 2)
    hold(@max, @depths, 1)
  end

  def propose(player, recipient, offer:, request:)
    Game::ProposeTrade.new.call(player:, recipient:, offer:, request:).value!
  end

  def revision(trade) = { revision: Game::Trade.find(trade.id).revision }

  def trade_rows = css_select(".social__trades .social-trade")

  def earn_goal_reward(player)
    week = Game::WeeklyGoal.week_start(Time.current) - 7
    Game::WeeklyGoal.find_or_create_by!(week_start: week) { it.assign_attributes(total: 200, target: 200) }
    Game::WeeklyContribution.create!(player_id: player.id, week_start: week, openings: 1)
    Game::GrantGoalReward.new.call(player:, week_start: week).value!
    week
  end

  test "the trades waiting on the player come first, each linking to its trade by token" do
    trading_friends
    theirs = propose(@hugo, @max, offer: { @soldier => 1 }, request: { @depths => 1 })
    yours = propose(@lea, @hugo, offer: { @depths => 1 }, request: { @portal => 2 })
    sign_in @hugo

    get social_path(locale: :en)

    assert_response :success
    assert_select "main h1.visually-hidden", "Social"
    rows = trade_rows
    assert_equal 2, rows.size
    assert_equal trade_path(locale: :en, token: yours.token), rows[0]["href"]
    assert_equal "Your turn", rows[0].at_css(".trade-chip--alert").text
    assert_match(/Lea/, rows[0].text)
    assert_equal trade_path(locale: :en, token: theirs.token), rows[1]["href"]
    assert_equal "Their turn", rows[1].at_css(".trade-chip--accent").text
    assert_match(/Max/, rows[1].text)
  end

  test "a row shows the friend, the turn and a pip per card on each side, labelled with who gives, never a card" do
    trading_friends
    propose(@hugo, @lea, offer: { @soldier => 1, @portal => 1 }, request: { @depths => 1 })
    sign_in @hugo

    get social_path(locale: :en)

    row = trade_rows.sole
    assert_match(/Lea/, row.text)
    sides = row.css(".social-trade__side")
    assert_equal [ "You", "Lea" ], sides.map { it.at_css(".social-trade__who").text }
    assert_equal [ "2", "1" ], sides.map { it.at_css(".social-trade__count").text }
    assert_equal %w[social-trade__pip--epic social-trade__pip--common], sides.first.css(".social-trade__pip").map { it["class"].split.last }
    assert_equal [ "social-trade__pip--rare" ], sides.last.css(".social-trade__pip").map { it["class"].split.last }
    assert_includes row.at_css(".social-trade__sides .visually-hidden").text, "You give 2 cards"
    assert_no_match(/Portal|Tin Soldier|Blue Depths/, row.text)
    assert_nil row.at_css(".card, img")
  end

  test "the five most recent ended trades show quietly under Recently, with their age" do
    trading_friends
    now = Time.current
    travel_to(now - 9.days) { propose(@hugo, @lea, offer: { @soldier => 1 }, request: { @depths => 1 }) }
    6.times do |hour|
      travel_to(now - 3.days + hour.hours) do
        trade = propose(@hugo, @lea, offer: { @portal => 1 }, request: { @depths => 1 })
        Game::DeclineTrade.new.call(player: @lea, trade_id: trade.id, **revision(trade)).value!
      end
    end
    travel_to(now - 1.day) do
      trade = propose(@hugo, @lea, offer: { @portal => 1 }, request: { @depths => 1 })
      Game::AcceptTrade.new.call(player: @lea, trade_id: trade.id, **revision(trade)).value!
    end
    sign_in @hugo

    get social_path(locale: :en)

    assert_select ".social__trades", false
    assert_select "#social-recent-heading", "Recently"
    rows = css_select(".social__recent .social-trade.social-trade--quiet")
    assert_equal 5, rows.size
    assert_equal [ "Done", "Closed", "Closed", "Closed", "Closed" ], rows.map { it.at_css(".trade-chip--muted").text }
    assert_equal "done 1 d ago", rows[0].at_css(".trade-row__when").text
    assert_equal "expired 2 d ago", rows[1].at_css(".trade-row__when").text
    assert_select ".social__recent .trade-chip--alert, .social__recent .trade-chip--accent", false
  end

  test "with no trade, a short empty line, and New trade still at the bottom" do
    sign_in @hugo

    get social_path(locale: :en)

    assert_select ".social-trade", false
    assert_select ".social__section .social__empty", "No trade in progress."
    assert_select ".social > .social__actions:last-child a.button--primary[href=?]", new_trade_path(locale: :en), "New trade"
  end

  test "the friends show with their presence, the open one linking to its profile, the private one plain" do
    trading_friends
    @max.update!(visibility: :private)
    sign_in @hugo

    get social_path(locale: :en)

    assert_select ".social__friends > li", 2
    assert_select ".social__friends a.social-friend[href=?]", friend_profile_path(locale: :en, token: @lea.token) do
      assert_select ".social-friend__name", "Lea"
      assert_select ".friends__presence"
    end
    assert_select ".social__friends span.social-friend" do
      assert_select ".social-friend__name", "Max"
      assert_select ".friends__presence--private", /Private profile/
    end
    assert_select ".social__friends a[href*='#{@max.token}']", false
  end

  test "with no friend, an empty line points to Add a friend" do
    sign_in @hugo

    get social_path(locale: :fr)

    assert_select ".social__friends", false
    assert_select ".social__empty", "Pas encore d'ami. Ajoutez-en un avec le bouton ci-dessous."
  end

  test "Add a friend leads to the invite panel of the Friends screen, New trade to a new trade" do
    sign_in @hugo

    get social_path(locale: :fr)

    assert_select ".social__actions a.button--secondary[href=?]", friends_path(locale: :fr, anchor: "friends-invite"), "Ajouter un ami"
    assert_select ".social__actions a.button--primary[href=?]", new_trade_path(locale: :fr), "Nouvel échange"
    assert_equal %w[Échanges Amis], css_select(".social__heading").first(2).map { it.text.strip }
  end

  test "the community goal shows with its progress, and its collect button when a reward waits" do
    sign_in @hugo

    get social_path(locale: :en)
    assert_select "#community-goal #community-goal-progress"
    assert_select "#goal-reward", false
    assert_includes css_select("turbo-cable-stream-source:not([channel=PlayerStreamChannel])")
      .map { Turbo::StreamsChannel.verified_stream_name(it["signed-stream-name"]) }, LiveStream.goal_streamables(:en).join(":")

    week = earn_goal_reward(@hugo)
    get social_path(locale: :en)

    assert_select "#community-goal #goal-reward.hub-goal__claim--ready form[action=?] button", goal_reward_path(locale: :en, week: week.iso8601),
      text: "Collect"
  end

  test "the feed is a link away, and the links to all trades and to friends carry the badge slots" do
    Game::Invitation.create!(sender_id: @lea.id, recipient_id: @hugo.id)
    sign_in @hugo

    get social_path(locale: :en)

    assert_select ".social a[href=?]", feed_path(locale: :en), /See the feed/
    assert_select ".social a.social__more[href=?] #plus-trades-badge.stream-slot", trades_path(locale: :en)
    assert_select ".social a.social__more[href=?] #plus-friends-badge.stream-slot .menu-item__badge--alert", friends_path(locale: :en), text: "1"
    assert_select "[style]", 0
  end

  test "the trades and the friends refresh each on their own signal" do
    sign_in @hugo

    get social_path(locale: :en)

    assert_select "section[data-controller='live-refresh'][data-live-refresh-signal-value='trades-updated'] #plus-trades-badge", 1
    assert_select "section[data-controller='live-refresh'][data-live-refresh-signal-value='friends-updated'] #plus-friends-badge", 1
  end
end

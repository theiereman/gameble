require "test_helper"
require_relative "../support/steam_sign_in"
require_relative "../support/holdings"
require_relative "../support/game_packs"

# The Social screen: the community goal, the trades in progress, waiting on
# the player first (never an ended one), the friends with their
# presence and the feed's latest entries; Add a friend and New trade follow the
# heading, shown last on a phone.
class SocialPageTest < ActionDispatch::IntegrationTest
  include GamePacks
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

  def trade_rows = css_select(".social__trades .social-trade:not(.social-trade--others)")

  def new_friend(number, name, online: true)
    friend = Accounts::Player.create!(steam_id: "7656119796051#{number.to_s.rjust(4, "0")}", persona_name: name,
      last_seen_at: online ? Time.current : 2.hours.ago)
    befriend(@hugo, friend)
    friend
  end

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
    assert_select "main h1.social__title", "Social"
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

  test "an ended trade never shows on Social, only in the trade list" do
    trading_friends
    trade = propose(@hugo, @lea, offer: { @portal => 1 }, request: { @depths => 1 })
    Game::AcceptTrade.new.call(player: @lea, trade_id: trade.id, **revision(trade)).value!
    sign_in @hugo

    get social_path(locale: :en)

    assert_select ".social-trade", false
    assert_select ".social__empty", "No trade in progress."
  end

  test "with no trade, a short empty line, and New trade still offered" do
    sign_in @hugo

    get social_path(locale: :en)

    assert_select ".social-trade", false
    assert_select ".social__section .social__empty", "No trade in progress."
    assert_select ".social > .social__actions a.button--primary[href=?]", new_trade_path(locale: :en), "New trade"
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
    assert_equal [ "Échanges", "Amis", "Fil d'activité" ], css_select(".social__heading").map { it.text.strip }
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
    assert_select ".social a.social__more[href=?] #plus-friends-badge.stream-slot .menu-item__badge--friends", friends_path(locale: :en), text: "1"
    assert_select "[style]", 0
  end

  test "the trades and the friends refresh each on their own signal" do
    sign_in @hugo

    get social_path(locale: :en)

    assert_select "section[data-controller='live-refresh'][data-live-refresh-signal-value='trades-updated'] #plus-trades-badge", 1
    assert_select "section[data-controller='live-refresh'][data-live-refresh-signal-value='friends-updated'] #plus-friends-badge", 1
  end

  def open_public_pack(player)
    create_pack(player, cards: [ fixture_tier_ids[3] ] * 5)
    Game::OpenPack.new.call(player:).value!
  end

  test "the screen opens on its heading and the two actions, then the goal, the trades, the friends and the feed" do
    sign_in @hugo

    get social_path(locale: :en)

    assert_select ".social > h1.social__title:first-child + .social__actions + .hub-goal + .social__trades-section " \
      "+ .social__friends-section + .social__feed + #reaction-status:last-child"
    assert_select ".social > .hub-goal#community-goal .hub-goal__about + .hub-goal__meter + .hub-goal__prize"
  end

  test "the feed preview shows the three latest entries with their reactions, live under its own id" do
    open_public_pack(@lea)
    sign_in @hugo

    get social_path(locale: :en)

    assert_select ".social__feed .social__head .live-marker"
    assert_select ".social__feed #social-feed-preview ul.social-feed__list > li.feed__entry", 3 do |entries|
      entries.each { assert_select it, "turbo-frame.feed__reactions", 1 }
    end
    assert_select "#feed-entries", false
    streams = css_select("turbo-cable-stream-source").map { Turbo::StreamsChannel.verified_stream_name(it["signed-stream-name"]) }
    assert_includes streams, LiveStream.social_feed_streamables(:en).join(":")
    assert_not_includes streams, LiveStream.feed_streamables(:en).join(":")
  end

  test "with no feed entry yet, the preview says so" do
    sign_in @hugo

    get social_path(locale: :fr)

    assert_select "#social-feed-preview .social__empty", "Rien pour l'instant."
    assert_select "#social-feed-preview li", 0
  end

  test "Social at full width carries no style attribute and its GET writes nothing" do
    trading_friends
    propose(@lea, @hugo, offer: { @depths => 1 }, request: { @portal => 1 })
    open_public_pack(@lea)
    sign_in @hugo
    get social_path(locale: :en)

    statements = []
    recorder = ->(*, payload) { statements << payload[:sql] if payload[:sql].match?(/\A\s*(INSERT|UPDATE|DELETE)\b/i) }
    ActiveSupport::Notifications.subscribed(recorder, "sql.active_record") { get social_path(locale: :en) }

    assert_response :success
    assert_empty statements
    assert_select "[style]", 0
  end

  test "a trade row carries its turn under the name and its tone, as well as the chip" do
    trading_friends
    propose(@lea, @hugo, offer: { @depths => 1 }, request: { @portal => 1 })
    sign_in @hugo

    get social_path(locale: :fr)

    row = trade_rows.sole
    assert_includes row["class"].split, "social-trade--alert"
    assert_equal "À vous", row.at_css(".trade-row__text > .social-trade__name + .social-trade__turn").text
    assert_equal "À vous", row.at_css(".trade-chip.social-trade__chip").text
  end

  test "the trades, friends and feed screens and a trade name Social as their parent at every width, the board keeping List on the phone" do
    trading_friends
    trade = propose(@lea, @hugo, offer: { @depths => 1 }, request: { @portal => 1 })
    sign_in @hugo

    [ trades_path(locale: :en), friends_path(locale: :en), feed_path(locale: :en) ].each do |path|
      get path
      back = css_select(".top-bar__start > a.top-bar__social-back").sole
      assert_equal [ "/en/social", "Social" ], [ back["href"], back.at_css(".button__label").text ], path
      assert_includes back["class"].split, "top-bar__phone-back", path
      assert_select ".top-bar__start > a.top-bar__previous", 1
    end

    get trade_path(locale: :en, token: trade.token)
    assert_equal "/en/trades", css_select(".top-bar__start > a.top-bar__phone-back").sole["href"]
    social = css_select(".top-bar__start > a.top-bar__social-back").sole
    assert_equal [ "/en/social", "Social" ], [ social["href"], social.at_css(".button__label").text ]
    assert_not_includes social["class"].split, "top-bar__phone-back"
  end

  test "past five open trades, four show, those waiting on the player first, and a fifth line names the rest with their turn" do
    hold(@hugo, @portal, 3)
    friends = %w[Ana Ben Cid Dan Eve Fay Gus Hal].each_with_index.map { |name, index| new_friend(index, name) }
    friends.each { hold(it, @depths, 1) }
    friends.first(5).each { propose(it, @hugo, offer: {}, request: { @portal => 1 }) }
    friends.last(3).each { propose(@hugo, it, offer: {}, request: { @depths => 1 }) }
    sign_in @hugo

    get social_path(locale: :en)

    assert_equal [ "Your turn" ] * 4, trade_rows.map { it.at_css(".social-trade__chip").text }
    others = css_select(".social__trades a.social-trade--others[href='#{trades_path(locale: :en)}']").sole
    hidden = friends.map(&:persona_name) - trade_rows.map { it.at_css(".social-trade__name").text }
    assert_equal 4, hidden.size
    assert_equal "#{hidden.first(3).join(", ")} and 1 other", others.at_css(".social-trade__name").text
    assert_equal "Your turn", others.at_css(".trade-chip--alert").text
  end

  test "exactly five open trades all show, with no line for the rest" do
    hold(@hugo, @portal, 3)
    5.times { |index| propose(@hugo, new_friend(index, "F#{index}").tap { hold(it, @depths, 1) }, offer: {}, request: { @depths => 1 }) }
    sign_in @hugo

    get social_path(locale: :fr)

    assert_equal 5, trade_rows.size
    assert_select ".social-trade--others", false
  end

  test "past five friends online, four show and a fifth line names the others online, leading to Friends" do
    names = %w[Ana Ben Cid Dan Eve Fay Gus]
    names.each_with_index { |name, index| new_friend(index, name) }
    sign_in @hugo

    get social_path(locale: :en)

    assert_select ".social__friends > li", 5
    shown = css_select(".social__friends .social-friend:not(.social-friend--others) .social-friend__name").map(&:text)
    hidden = names - shown
    others = css_select(".social__friends a.social-friend--others[href='#{friends_path(locale: :en)}']").sole
    assert_equal "#{hidden[0]}, #{hidden[1]} and #{hidden[2]} online", others.at_css(".social-friend__name").text
  end

  test "with five friends online or fewer, those online come first and the offline fill up to five" do
    %w[On1 On2 On3].each_with_index { |name, index| new_friend(index, name) }
    %w[Off1 Off2 Off3 Off4].each_with_index { |name, index| new_friend(index + 10, name, online: false) }
    sign_in @hugo

    get social_path(locale: :en)

    names = css_select(".social__friends .social-friend__name").map(&:text)
    assert_equal 5, names.size
    assert_equal %w[On1 On2 On3], names.first(3).sort
    assert names.last(2).all? { it.start_with?("Off") }
    assert_select ".social-friend--others", false
  end
end

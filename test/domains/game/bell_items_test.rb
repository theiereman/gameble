require "test_helper"
require_relative "../../support/game_packs"
require_relative "../../support/feed_reactions"

# The bell's lines, from current state: the friend requests received, the
# trades waiting on the player, the daily capsule while collectable, and the
# weekly mission, its reward line while a reward waits, and the player's
# feed entries that others reacted to.
class Game::BellItemsTest < ActiveSupport::TestCase
  include GamePacks
  include FeedReactions

  NOW = Time.utc(2026, 10, 7, 15, 0)

  setup do
    @hugo = accounts_players(:player)
    @max = accounts_players(:moderator)
    @eve = accounts_players(:administrator)
  end

  def items(player = @hugo, now: NOW) = Game::BellItems.call(player, now:)

  def invite(from, to, status: "pending")
    Game::Invitation.create!(sender_id: from.id, recipient_id: to.id, status:)
  end

  def trade(from, to, status: "open", proposed_at: NOW - 1.hour, expires_at: NOW + 1.day)
    low, high = [ from.id, to.id ].minmax
    Game::Trade.create!(low_player_id: low, high_player_id: high, proposer_id: from.id, recipient_id: to.id, status:, proposed_at:, expires_at:)
  end

  test "a trade waiting on the player is a line with its token, its proposer and its revision" do
    waiting = trade(@max, @hugo)

    line = items.trades.sole

    assert_equal waiting.token, line.token
    assert_equal @max, line.player
    assert_equal waiting.revision, line.revision
  end

  test "a trade waiting on the friend, closed, expired or from a banned proposer is no line" do
    trade(@hugo, @max)
    trade(@max, @hugo, status: "declined")
    trade(@max, @hugo, expires_at: NOW - 1.minute)
    trade(@eve, @hugo)
    @eve.update_columns(banned_at: NOW)

    assert_empty items.trades
  end

  test "a trade countered back to the player comes with its new revision" do
    waiting = trade(@max, @hugo)
    before = items.trades.sole.revision

    waiting.update!(proposed_at: NOW - 1.minute)

    assert_not_equal before, items.trades.sole.revision
  end

  test "a pending request received is a line with its token and its sender; sent, answered or banned ones are not" do
    received = invite(@max, @hugo)
    invite(@hugo, @eve)
    invite(@eve, @hugo, status: "ignored")

    line = items.invitations.sole
    assert_equal received.token, line.token
    assert_equal @max, line.player

    @max.update_columns(banned_at: NOW)
    assert_empty items.invitations
  end

  test "each kind holds five lines at most: the trades expiring soonest, the newest requests" do
    players = Array.new(6) { |index| Accounts::Player.create!(steam_id: "7656119800000#{format("%04d", index)}") }
    trades = players.each_with_index.map { |player, index| trade(player, @hugo, expires_at: NOW + (6 - index).hours) }
    invitations = players.map { |player| invite(player, @hugo) }

    assert_equal trades.reverse.first(5).map(&:token), items.trades.map(&:token)
    assert_equal invitations.reverse.first(5).map(&:token), items.invitations.map(&:token)
  end

  test "the daily capsule is a line for the day while it is collectable" do
    assert_equal NOW.to_date, items.daily

    Game::DailyBonusClaim.create!(player_id: @hugo.id, day: NOW.to_date, pack_id: create_pack(@hugo, kind: :bonus).id)
    assert_nil items.daily

    assert_equal NOW.to_date + 1, items(now: NOW + 1.day).daily
  end

  test "with no published season there is no daily line" do
    without_published_season { assert_nil items.daily }
  end

  test "the mission line is the week's, with its target, while no reward waits" do
    Game::WeeklyGoal.create!(week_start: Date.new(2026, 10, 5), total: 40, target: 600)

    goal = items.goal

    assert_equal Date.new(2026, 10, 5), goal.week_start
    assert_not goal.reward_ready
    assert_equal 600, goal.target
    assert_not goal.reached
  end

  test "the week's line knows once the mission is accomplished" do
    Game::WeeklyGoal.create!(week_start: Date.new(2026, 10, 5), total: 600, target: 600)

    assert items.goal.reached
  end

  test "an unclaimed reward replaces the week's line; once claimed, the week's line comes back" do
    reward = Game::GoalReward.create!(player_id: @hugo.id, week_start: Date.new(2026, 9, 28))

    goal = items.goal
    assert goal.reward_ready
    assert_equal Date.new(2026, 9, 28), goal.week_start

    reward.update_columns(pack_id: create_pack(@hugo, kind: :reward).id)
    assert_not items.goal.reward_ready
  end

  test "an answered proposal is a line with its friend, its outcome and its closing time, until the trade is opened" do
    answered = trade(@hugo, @max, status: "declined")
    answered.update!(closed_at: NOW - 1.hour)

    line = items.updates.sole

    assert_equal [ answered.token, @max, "declined", answered.closed_at ], [ line.token, line.player, line.outcome, line.closed_at ]

    Game::MarkTradeSeen.new.call(player: @hugo, trade_token: answered.token, now: NOW)

    assert_empty items.updates
  end

  test "a trade the friend answered is no update for the friend, and one countered back stays a waiting line" do
    trade(@max, @hugo, status: "accepted").update!(closed_at: NOW - 1.hour)
    trade(@max, @hugo)

    assert_empty items.updates
    assert_equal 1, items.trades.size
  end

  def reactions(player = @hugo) = Game::BellItems.call(player).reactions

  test "the market lines are the player's own notices, never another's" do
    listing = Game::Market::Listing.create!(seller: @max, card_season_id: catalog_card_seasons(:common_card_one).id,
      settings_id: Game::Market::Settings.create!(Game::Market::StartingSettings::ATTRIBUTES.merge(open: true)).id, starting_price: 1_300,
      current_price: 1_300, duration_hours: 24, ends_at: 1.day.from_now)
    Game::Market::Notice.record(player_id: @hugo.id, listing_id: listing.id, kind: "outbid", other_player_id: @eve.id, amount: 2_000, at: NOW)

    assert_equal [ listing.token ], items.market.map(&:token)
    assert_empty items(@eve).market
  end

  def noticed_at(entry) = Game::ReactionNotice.where(feed_entry_id: entry.id).maximum(:created_at)

  def notice_age(entry, reactor, age)
    Game::ReactionNotice.where(feed_entry_id: entry.id, reactor_id: reactor.id).update_all(created_at: age.ago)
  end

  test "an entry another player reacted to is a line naming the latest public reactor, keyed by its latest notice" do
    @max.update!(persona_name: "Max")
    @eve.update!(persona_name: "Eve")
    entry = feed_entry_of(@hugo)
    react(@max, entry, "heart")
    react(@eve, entry, "middle_finger")

    line = reactions.sole

    assert_equal [ entry.token, "Eve", 1, 2, noticed_at(entry) ], [ line.token, line.name, line.others, line.count, line.noticed_at ]
  end

  test "a line tells the kinds chosen, most chosen first, and what the entry shows" do
    entry = feed_entry_of(@hugo)
    react(@max, entry, "wow")
    react(@eve, entry, "heart")
    react(Accounts::Player.create!(steam_id: "76561198000001234"), entry, "heart")

    line = reactions.sole

    assert_equal({ "heart" => 2, "wow" => 1 }, line.kinds)
    assert_equal [ "heart", "wow" ], line.kinds.keys
    assert_equal [ "Portal", nil, nil ], [ line.subject.card, line.subject.partner_card, line.subject.set ]
  end

  test "a withdrawn reaction keeps its notice: the line counts the players reacting now and keeps its latest notice" do
    @max.update!(persona_name: "Max")
    @eve.update!(persona_name: "Eve")
    entry = feed_entry_of(@hugo)
    react(@max, entry, "heart")
    react(@eve, entry, "wow")
    react(@eve, entry, nil)

    line = reactions.sole

    assert_equal [ "Max", 0, 1, noticed_at(entry) ], [ line.name, line.others, line.count, line.noticed_at ]
  end

  test "a new reactor after a released one moves the line's time forward" do
    entry = feed_entry_of(@hugo)
    react(@max, entry, "heart")
    react(@eve, entry, "gg")
    notice_age(entry, @max, 2.hours)
    notice_age(entry, @eve, 1.hour)
    before = reactions.sole.noticed_at

    Game::ReleasePlayer.new.call(player: @eve).value!
    react(Accounts::Player.create!(steam_id: "76561198000001234"), entry, "wow")

    assert_operator reactions.sole.noticed_at, :>, before
  end

  test "an entry whose every reaction was withdrawn is no line" do
    entry = feed_entry_of(@hugo)
    react(@max, entry, "heart")
    react(@max, entry, nil)

    assert_empty reactions
  end

  test "a reactor whose profile is not public is counted, not named" do
    @max.update!(persona_name: "Max", visibility: "friends_only")
    entry = feed_entry_of(@hugo)
    react(@max, entry, "heart")

    line = reactions.sole

    assert_nil line.name
    assert_equal [ 0, 1 ], [ line.others, line.count ]
  end

  test "a banned reactor no longer counts" do
    @max.update!(persona_name: "Max")
    entry = feed_entry_of(@hugo)
    react(@max, entry, "heart")
    react(@eve, entry, "gg")

    @max.update_columns(banned_at: Time.current)

    line = reactions.sole
    assert_nil line.name
    assert_equal [ 1, noticed_at(entry) ], [ line.count, line.noticed_at ]
  end

  test "the player's own reaction and reactions to others' entries are no line" do
    react(@hugo, feed_entry_of(@hugo), "heart")
    react(@hugo, feed_entry_of(@max), "heart")

    assert_empty reactions
  end

  test "a line lasts 7 days after the latest first reaction" do
    entry = feed_entry_of(@hugo)
    react(@max, entry, "heart")
    notice_age(entry, @max, 8.days)

    assert_empty reactions

    react(@eve, entry, "heart")
    assert_equal 2, reactions.sole.count
  end

  test "five entries at most, the most recently reacted to first" do
    entries = Array.new(6) { feed_entry_of(@hugo) }
    entries.each_with_index do |entry, index|
      react(@max, entry, "heart")
      notice_age(entry, @max, (6 - index).hours)
    end

    assert_equal entries.reverse.first(5).map(&:token), reactions.map(&:token)
  end
end

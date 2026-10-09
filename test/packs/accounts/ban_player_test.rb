require "test_helper"

class Accounts::BanPlayerTest < ActiveSupport::TestCase
  setup do
    @moderator = accounts_players(:moderator)
    @administrator = accounts_players(:administrator)
    @target = accounts_players(:player)
    @portal = catalog_card_seasons(:portal_one).id
    @depths = catalog_card_seasons(:rare_card_one).id
  end

  def ban(player = @target, staff: @moderator, reason: "Insults in the name") = Accounts::BanPlayer.new.call(staff:, player:, reason:)

  def history = Accounts::ModerationAction.order(:id).map { [ it.kind, it.player, it.staff, it.reason ] }

  def stranger(number) = Accounts::Player.create!(steam_id: "7656119796031#{number.to_s.rjust(4, "0")}")

  def report(reported, reporter: stranger(@reporters = (@reporters || 100) + 1), reason: "cheating")
    Accounts::Report.create!(reporter:, reported:, reason:)
  end

  def events(type) = Rails.configuration.event_store.read.of_type(type).to_a

  def befriend(first, second)
    low, high = [ first.id, second.id ].minmax
    Game::Friendship.create!(low_player_id: low, high_player_id: high)
  end

  def assert_unchanged(player, code, staff: @moderator, reason: "Insults in the name")
    banned_at = player.reload.banned_at
    assert_no_difference [ -> { events(Accounts::PlayerBanned).size }, -> { Accounts::ModerationAction.count } ] do
      assert_equal Dry::Monads::Failure(code), ban(player, staff:, reason:)
    end
    assert_equal [ banned_at ], [ player.reload.banned_at ]
  end

  test "a moderator bans a player: banned_at is set, the open reports handled, the stream key rotated, PlayerBanned carries the ids" do
    open = report(@target)
    handled = report(@target, reason: "other").tap { it.update!(handled_at: 2.days.ago) }
    handled_at = handled.reload.handled_at
    other = report(@administrator)
    stream_key = @target.stream_key

    result = travel_to(Time.utc(2026, 10, 9, 12)) { ban }

    assert_equal @target, result.value!
    @target.reload
    assert_equal Time.utc(2026, 10, 9, 12), @target.banned_at
    assert_not_equal stream_key, @target.stream_key
    assert_equal Time.utc(2026, 10, 9, 12), open.reload.handled_at
    assert_equal handled_at, handled.reload.handled_at
    assert_nil other.reload.handled_at
    published = Rails.configuration.event_store.read.stream("Accounts::Player$#{@target.id}").of_type(Accounts::PlayerBanned).to_a
    assert_equal [ { player_id: @target.id, staff_id: @moderator.id } ], published.map(&:data)
  end

  test "the ban drops the player's friendships and cancels their open trade through Game's handler" do
    friend = @administrator
    befriend(@target, friend)
    befriend(@moderator, friend)
    Game::Holding.create!(player_id: friend.id, card_season_id: @portal, quantity: 2)
    Game::Holding.create!(player_id: @target.id, card_season_id: @depths, quantity: 1)
    trade = Game::ProposeTrade.new.call(player: friend, recipient: @target, offer: { @portal => 1 }, request: { @depths => 1 }).value!

    ban.value!

    assert_equal "cancelled", trade.reload.status
    assert_equal 0, Game::Holding.find_by(player_id: friend.id, card_season_id: @portal).reserved
    assert_not Game::FriendshipBetween.call(@target, friend)
    assert Game::FriendshipBetween.call(@moderator, friend)
  end

  test "an administrator bans a moderator" do
    assert ban(@moderator, staff: @administrator).success?
    assert_predicate @moderator.reload, :banned?
  end

  test "a moderator does not ban another moderator" do
    other_moderator = stranger(5).tap { it.update!(role: :moderator) }
    open = report(other_moderator)

    assert_unchanged(other_moderator, :outranked)
    assert_nil open.reload.handled_at
  end

  test "no one bans an administrator" do
    assert_unchanged(@administrator, :outranked)
    other_administrator = stranger(1).tap { it.update!(role: :administrator) }
    assert_unchanged(other_administrator, :outranked, staff: @administrator)
  end

  test "no one bans themselves, which is said before the rank" do
    assert_unchanged(@moderator, :cannot_ban_self)
    assert_unchanged(@administrator, :cannot_ban_self, staff: @administrator)
  end

  test "a promotion read under the lock refuses the ban" do
    stale = Accounts::Player.find(@target.id)
    @target.update!(role: :moderator)

    assert_unchanged(stale, :outranked)
  end

  test "a banned player is not banned twice" do
    assert_unchanged(accounts_players(:banned), :already_banned)
  end

  test "an unknown or deleted player is not found" do
    assert_equal Dry::Monads::Failure(:player_not_found), ban(nil)
    assert_equal Dry::Monads::Failure(:player_not_found), ban(Accounts::Player.new)
    deleted = stranger(2)
    Accounts::DeletePlayer.new.call(player: deleted).value!
    assert_unchanged(deleted, :player_not_found)
  end

  test "only a moderator or an administrator in good standing bans" do
    assert_unchanged(@target, :staff_required, staff: nil)
    assert_unchanged(@target, :staff_required, staff: stranger(3))
    banned_moderator = stranger(4).tap { it.update!(role: :moderator, banned_at: 1.day.ago) }
    assert_unchanged(@target, :staff_required, staff: banned_moderator)
  end

  test "the refusal is re-read under the lock" do
    stale = Accounts::Player.find(@target.id)
    ban.value!

    assert_no_difference -> { events(Accounts::PlayerBanned).size } do
      assert_equal Dry::Monads::Failure(:already_banned), ban(stale)
    end
  end

  test "the refusal tells the queue what it would answer" do
    assert_nil Accounts::BanPlayer.refusal(staff: @moderator, player: @target)
    assert_equal :outranked, Accounts::BanPlayer.refusal(staff: @moderator, player: @administrator)
    assert_nil Accounts::BanPlayer.refusal(staff: @administrator, player: @moderator)
    assert_equal :cannot_ban_self, Accounts::BanPlayer.refusal(staff: @moderator, player: @moderator)
    assert_equal :staff_required, Accounts::BanPlayer.refusal(staff: @target, player: @moderator)
  end

  test "the ban joins the moderation history with the player, the member of staff, the cleaned reason and its time" do
    travel_to(Time.utc(2026, 10, 9, 12)) { ban(reason: "  Insults\u200B in\u00A0the   name ") }.value!

    action = Accounts::ModerationAction.sole
    assert_equal [ "ban", @target, @moderator, "Insults in the name" ], [ action.kind, action.player, action.staff, action.reason ]
    assert_equal Time.utc(2026, 10, 9, 12), action.created_at
    assert_equal @target.reload.banned_at, action.created_at
  end

  test "a ban without a reason is refused: missing, empty, blank or invisible" do
    [ nil, "", "   ", "\u200B\u3000\u202E", 42, [ "Insults" ] ].each do |reason|
      assert_unchanged(@target, :reason_required, reason:)
    end
    assert_empty history
  end

  test "a reason longer than 500 characters once cleaned is refused; 500 is kept" do
    open = report(@target)

    assert_unchanged(@target, :reason_too_long, reason: "a" * 501)
    assert_nil open.reload.handled_at

    assert ban(reason: " #{"a" * 500}\u200B ").success?
    assert_equal [ [ "ban", @target, @moderator, "a" * 500 ] ], history
  end

  test "the refusals come before the reason, and a refused ban leaves no line in the history" do
    assert_unchanged(@target, :staff_required, staff: stranger(6), reason: "")
    assert_unchanged(@administrator, :outranked, reason: nil)
    assert_unchanged(@moderator, :cannot_ban_self, reason: "")
    assert_unchanged(accounts_players(:banned), :already_banned, reason: "a" * 501)
    assert_empty history
  end

  test "a ban rolled back by a refusal read under the lock leaves no line in the history" do
    stale = Accounts::Player.find(@target.id)
    @target.update!(role: :moderator)

    assert_unchanged(stale, :outranked)
    assert_empty history
  end
end

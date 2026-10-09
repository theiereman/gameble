require "test_helper"

class Accounts::UnbanPlayerTest < ActiveSupport::TestCase
  setup do
    @moderator = accounts_players(:moderator)
    @target = accounts_players(:player)
  end

  def unban(player = @target, staff: @moderator) = Accounts::UnbanPlayer.new.call(staff:, player:)

  def stranger(number) = Accounts::Player.create!(steam_id: "7656119796032#{number.to_s.rjust(4, "0")}")

  def unbanned_events = Rails.configuration.event_store.read.of_type(Accounts::PlayerUnbanned).to_a

  test "a moderator lifts a ban: the player is in good standing again, the reports the ban handled stay handled" do
    report = Accounts::Report.create!(reporter: stranger(1), reported: @target, reason: "cheating")
    Accounts::BanPlayer.new.call(staff: @moderator, player: @target, reason: "Rude name").value!

    result = unban

    assert_equal @target, result.value!
    assert_nil @target.reload.banned_at
    assert_includes Accounts::Player.in_good_standing, @target
    assert_not_nil report.reload.handled_at
    published = Rails.configuration.event_store.read.stream("Accounts::Player$#{@target.id}").of_type(Accounts::PlayerUnbanned).to_a
    assert_equal [ { player_id: @target.id, staff_id: @moderator.id } ], published.map(&:data)
  end

  test "an administrator lifts a ban set from the console" do
    banned = accounts_players(:banned)

    assert unban(banned, staff: accounts_players(:administrator)).success?
    assert_not banned.reload.banned?
  end

  test "a moderator does not lift a moderator's ban; an administrator does" do
    banned_moderator = stranger(4).tap { it.update!(role: :moderator, banned_at: 1.day.ago) }

    assert_equal Dry::Monads::Failure(:outranked), unban(banned_moderator)
    assert_predicate banned_moderator.reload, :banned?
    assert_empty unbanned_events

    assert unban(banned_moderator, staff: accounts_players(:administrator)).success?
    assert_not banned_moderator.reload.banned?
  end

  test "no one lifts an administrator's ban" do
    banned_administrator = stranger(5).tap { it.update!(role: :administrator, banned_at: 1.day.ago) }

    [ @moderator, accounts_players(:administrator) ].each do |staff|
      assert_equal Dry::Monads::Failure(:outranked), unban(banned_administrator, staff:)
    end
    assert_predicate banned_administrator.reload, :banned?
    assert_empty unbanned_events
  end

  test "a promotion read under the lock refuses the unban" do
    banned = accounts_players(:banned)
    stale = Accounts::Player.find(banned.id)
    banned.update!(role: :moderator)

    assert_equal Dry::Monads::Failure(:outranked), unban(stale)
    assert_predicate banned.reload, :banned?
    assert_empty unbanned_events
  end

  test "a member of staff demoted or banned since they were read is refused" do
    banned = accounts_players(:banned)
    demoted = stranger(5).tap { it.update!(role: :moderator) }
    stale_demoted = Accounts::Player.find(demoted.id)
    demoted.update!(role: :player)
    sanctioned = stranger(6).tap { it.update!(role: :moderator) }
    stale_sanctioned = Accounts::Player.find(sanctioned.id)
    sanctioned.update!(banned_at: 1.minute.ago)

    assert_equal Dry::Monads::Failure(:staff_required), unban(banned, staff: stale_demoted)
    assert_equal Dry::Monads::Failure(:staff_required), unban(banned, staff: stale_sanctioned)
    assert_predicate banned.reload, :banned?
    assert_empty unbanned_events
  end

  test "the refusal tells the banned list what it would answer" do
    banned = accounts_players(:banned)

    assert_nil Accounts::UnbanPlayer.refusal(staff: @moderator, player: banned)
    assert_equal :not_banned, Accounts::UnbanPlayer.refusal(staff: @moderator, player: @target)
    assert_equal :outranked, Accounts::UnbanPlayer.refusal(staff: @moderator, player: accounts_players(:administrator))
    assert_equal :staff_required, Accounts::UnbanPlayer.refusal(staff: @target, player: banned)
    assert_equal :player_not_found, Accounts::UnbanPlayer.refusal(staff: @moderator, player: nil)
  end

  test "a player who is not banned is refused, without an event" do
    assert_no_difference -> { unbanned_events.size } do
      assert_equal Dry::Monads::Failure(:not_banned), unban
    end
  end

  test "the refusal is re-read under the lock" do
    banned = accounts_players(:banned)
    stale = Accounts::Player.find(banned.id)
    unban(banned).value!

    assert_no_difference -> { unbanned_events.size } do
      assert_equal Dry::Monads::Failure(:not_banned), unban(stale)
    end
  end

  test "an unknown or deleted player is not found" do
    deleted = stranger(2)
    Accounts::DeletePlayer.new.call(player: deleted).value!

    [ nil, Accounts::Player.new, deleted ].each do |player|
      assert_equal Dry::Monads::Failure(:player_not_found), unban(player)
    end
    assert_empty unbanned_events
  end

  test "only a moderator or an administrator in good standing lifts a ban" do
    banned = accounts_players(:banned)

    [ nil, @target, stranger(3).tap { it.update!(role: :administrator, banned_at: 1.day.ago) } ].each do |staff|
      assert_equal Dry::Monads::Failure(:staff_required), unban(banned, staff:)
    end
    assert_predicate banned.reload, :banned?
    assert_empty unbanned_events
  end

  test "the lifted ban joins the moderation history, without a reason" do
    banned = accounts_players(:banned)

    travel_to(Time.utc(2026, 10, 9, 13)) { unban(banned) }.value!

    action = Accounts::ModerationAction.sole
    assert_equal [ "unban", banned, @moderator, nil ], [ action.kind, action.player, action.staff, action.reason ]
    assert_equal Time.utc(2026, 10, 9, 13), action.created_at
  end

  test "a refused unban leaves no line in the history" do
    banned = accounts_players(:banned)
    stale = Accounts::Player.find(banned.id)
    banned.update!(role: :moderator)

    assert_equal Dry::Monads::Failure(:not_banned), unban
    assert_equal Dry::Monads::Failure(:outranked), unban(stale)
    assert_equal Dry::Monads::Failure(:staff_required), unban(banned, staff: @target)
    assert_equal 0, Accounts::ModerationAction.count
  end
end

require "test_helper"

class Accounts::DismissReportsTest < ActiveSupport::TestCase
  setup do
    @moderator = accounts_players(:moderator)
    @target = accounts_players(:player)
  end

  def dismiss(player = @target, staff: @moderator) = Accounts::DismissReports.new.call(staff:, player:)

  def stranger(number) = Accounts::Player.create!(steam_id: "7656119796033#{number.to_s.rjust(4, "0")}")

  def report(reported, number) = Accounts::Report.create!(reporter: stranger(number), reported:, reason: "harassment")

  def dismissed_events = Rails.configuration.event_store.read.of_type(Accounts::ReportsDismissed).to_a

  test "a moderator classes a player's open reports, leaving the player and the other players' reports alone" do
    first = report(@target, 1)
    second = report(@target, 2)
    other = report(@moderator, 3)

    result = travel_to(Time.utc(2026, 10, 9, 12)) { dismiss }

    assert_equal 2, result.value!
    assert_equal [ Time.utc(2026, 10, 9, 12) ] * 2, [ first, second ].map { it.reload.handled_at }
    assert_nil other.reload.handled_at
    assert_not @target.reload.banned?
    published = Rails.configuration.event_store.read.stream("Accounts::Player$#{@target.id}").of_type(Accounts::ReportsDismissed).to_a
    assert_equal [ { player_id: @target.id, staff_id: @moderator.id } ], published.map(&:data)
  end

  test "a player without open reports is refused, without an event" do
    report(@target, 4).update!(handled_at: 1.day.ago)

    assert_equal Dry::Monads::Failure(:no_open_reports), dismiss
    assert_empty dismissed_events
  end

  test "an unknown or deleted player is not found" do
    deleted = stranger(5)
    report(deleted, 6)
    Accounts::DeletePlayer.new.call(player: deleted).value!

    [ nil, Accounts::Player.new, deleted ].each do |player|
      assert_equal Dry::Monads::Failure(:player_not_found), dismiss(player)
    end
    assert_empty dismissed_events
  end

  test "no one classes the reports against themselves" do
    open = report(@moderator, 9)

    assert_equal Dry::Monads::Failure(:cannot_dismiss_self), dismiss(@moderator)
    assert_nil open.reload.handled_at
    assert_empty dismissed_events
    assert_equal :cannot_dismiss_self, Accounts::DismissReports.refusal(staff: @moderator, player: @moderator)
    assert_nil Accounts::DismissReports.refusal(staff: @moderator, player: @target)
  end

  test "a moderator does not class a moderator's reports; an administrator does" do
    other_moderator = stranger(10).tap { it.update!(role: :moderator) }
    open = report(other_moderator, 11)

    assert_equal Dry::Monads::Failure(:outranked), dismiss(other_moderator)
    assert_nil open.reload.handled_at
    assert_empty dismissed_events

    assert_equal 1, dismiss(other_moderator, staff: accounts_players(:administrator)).value!
    assert_not_nil open.reload.handled_at
  end

  test "no one classes an administrator's reports" do
    administrator = accounts_players(:administrator)
    other_administrator = stranger(12).tap { it.update!(role: :administrator) }
    open = report(administrator, 13)

    assert_equal Dry::Monads::Failure(:outranked), dismiss(administrator)
    assert_equal Dry::Monads::Failure(:outranked), dismiss(administrator, staff: other_administrator)
    assert_nil open.reload.handled_at
    assert_empty dismissed_events
  end

  test "classing one's own reports is refused before the rank" do
    administrator = accounts_players(:administrator)
    report(administrator, 14)

    assert_equal Dry::Monads::Failure(:cannot_dismiss_self), dismiss(administrator, staff: administrator)
    assert_equal :outranked, Accounts::DismissReports.refusal(staff: @moderator, player: administrator)
  end

  test "a promotion read under the lock refuses the dismissal" do
    open = report(@target, 15)
    stale = Accounts::Player.find(@target.id)
    @target.update!(role: :moderator)

    assert_equal Dry::Monads::Failure(:outranked), dismiss(stale)
    assert_nil open.reload.handled_at
    assert_empty dismissed_events
  end

  test "only a moderator or an administrator in good standing classes reports" do
    open = report(@target, 7)

    [ nil, accounts_players(:banned).tap { it.update!(role: :moderator) }, stranger(8) ].each do |staff|
      assert_equal Dry::Monads::Failure(:staff_required), dismiss(staff:)
    end
    assert_nil open.reload.handled_at
    assert dismiss(staff: accounts_players(:administrator)).success?
  end

  test "the dismissal joins the moderation history, without a reason" do
    report(@target, 16)

    travel_to(Time.utc(2026, 10, 9, 14)) { dismiss }.value!

    action = Accounts::ModerationAction.sole
    assert_equal [ "dismissal", @target, @moderator, nil ], [ action.kind, action.player, action.staff, action.reason ]
    assert_equal Time.utc(2026, 10, 9, 14), action.created_at
  end

  test "a refused dismissal, or one with no open report, leaves no line in the history" do
    report(@target, 17).update!(handled_at: 1.day.ago)
    administrator = accounts_players(:administrator)
    report(administrator, 18)

    assert_equal Dry::Monads::Failure(:no_open_reports), dismiss
    assert_equal Dry::Monads::Failure(:outranked), dismiss(administrator)
    assert_equal Dry::Monads::Failure(:staff_required), dismiss(staff: @target)
    assert_equal 0, Accounts::ModerationAction.count
  end
end

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

  test "only a moderator or an administrator in good standing classes reports" do
    open = report(@target, 7)

    [ nil, accounts_players(:banned).tap { it.update!(role: :moderator) }, stranger(8) ].each do |staff|
      assert_equal Dry::Monads::Failure(:staff_required), dismiss(staff:)
    end
    assert_nil open.reload.handled_at
    assert dismiss(staff: accounts_players(:administrator)).success?
  end
end

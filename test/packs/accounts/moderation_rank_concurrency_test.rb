require "test_helper"
require_relative "../../support/lock_races"

# The rank rule and the reports under the player's lock: a promotion that
# commits while a ban or a dismissal waits makes it refuse, and a dismissal
# that waits on a ban finds the reports handled. Each thread has its own
# connection, so the test commits for real; it uses players of its own and
# removes them afterwards.
class Accounts::ModerationRankConcurrencyTest < ActiveSupport::TestCase
  include LockRaces

  self.use_transactional_tests = false

  setup do
    @moderator = accounts_players(:moderator)
    @target = Accounts::Player.create!(steam_id: "76561197960390301")
    @reporter = Accounts::Player.create!(steam_id: "76561197960390302")
    @report = Accounts::Report.create!(reporter: @reporter, reported: @target, reason: "cheating")
  end

  teardown do
    ids = [ @target.id, @reporter.id ]
    Accounts::Report.where(reported_id: ids).or(Accounts::Report.where(reporter_id: ids)).delete_all
    connection = ActiveRecord::Base.connection
    streams = ids.flat_map { |id| [ Game::Operation.stream_name(id), "Accounts::Player$#{id}" ] }
    event_ids = connection.select_values(ActiveRecord::Base.sanitize_sql_array([ "SELECT event_id FROM event_store_events_in_streams WHERE stream IN (?)", streams ]))
    connection.exec_delete(ActiveRecord::Base.sanitize_sql_array([ "DELETE FROM event_store_events_in_streams WHERE event_id IN (?)", event_ids ])) if event_ids.any?
    connection.exec_delete(ActiveRecord::Base.sanitize_sql_array([ "DELETE FROM event_store_events WHERE event_id IN (?)", event_ids ])) if event_ids.any?
    Accounts::Player.where(id: ids).delete_all
  end

  def events(type) = Rails.configuration.event_store.read.stream("Accounts::Player$#{@target.id}").of_type(type).to_a

  # The target as a request read it, before the race.
  def stale_target = Accounts::Player.find(@target.id)

  def promote = -> { Accounts::Player.find(@target.id).update!(role: :moderator) }

  test "a promotion that commits while a ban waits on the row refuses the ban" do
    stale = stale_target

    _, banning = first_holding_the_lock(promote, -> { Accounts::BanPlayer.new.call(staff: @moderator, player: stale) })

    assert_equal Dry::Monads::Failure(:outranked), banning
    assert_not @target.reload.banned?
    assert_nil @report.reload.handled_at
    assert_empty events(Accounts::PlayerBanned)
  end

  test "a promotion that commits while a dismissal waits on the row refuses the dismissal" do
    stale = stale_target

    _, dismissal = first_holding_the_lock(promote, -> { Accounts::DismissReports.new.call(staff: @moderator, player: stale) })

    assert_equal Dry::Monads::Failure(:outranked), dismissal
    assert_nil @report.reload.handled_at
    assert_empty events(Accounts::ReportsDismissed)
  end

  test "a dismissal that waits on a ban finds the reports handled" do
    stale = stale_target
    ban = -> { Accounts::BanPlayer.new.call(staff: @moderator, player: Accounts::Player.find(@target.id)) }

    banning, dismissal = first_holding_the_lock(ban, -> { Accounts::DismissReports.new.call(staff: @moderator, player: stale) })

    assert banning.success?
    assert_equal Dry::Monads::Failure(:no_open_reports), dismissal
    assert_predicate @target.reload, :banned?
    assert_not_nil @report.reload.handled_at
    assert_equal 1, events(Accounts::PlayerBanned).size
    assert_empty events(Accounts::ReportsDismissed)
  end
end

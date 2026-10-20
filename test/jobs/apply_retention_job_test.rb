require "test_helper"

class ApplyRetentionJobTest < ActiveSupport::TestCase
  setup do
    @now = Time.current.change(usec: 0)
    @moderator = accounts_players(:moderator)
    @player = accounts_players(:player)
  end

  def new_player(number, **attributes)
    Accounts::Player.create!(steam_id: "7656119796043#{number.to_s.rjust(4, "0")}", **attributes)
  end

  def seen(player, ago) = player.tap { it.update_columns(last_seen_at: @now - ago, updated_at: @now - ago) }

  def run_job
    log = StringIO.new
    logger = Rails.logger
    Rails.logger = ActiveSupport::Logger.new(log)
    travel_to(@now) { Accounts::ApplyRetentionJob.perform_now }
    log.string
  ensure
    Rails.logger = logger
  end

  # Runs `before` ahead of Accounts::DeleteInactivePlayer's call for each
  # player the job picks.
  def before_each_deletion(&before)
    original = Accounts::DeleteInactivePlayer.method(:new)
    Accounts::DeleteInactivePlayer.define_singleton_method(:new) do |*args, **options|
      operation = original.call(*args, **options)
      operation.define_singleton_method(:call) do |player:, now:|
        before.call(player, now)
        super(player:, now:)
      end
      operation
    end
  end

  teardown do
    if Accounts::DeleteInactivePlayer.singleton_class.method_defined?(:new, false)
      Accounts::DeleteInactivePlayer.singleton_class.remove_method(:new)
    end
  end

  test "deletes the idle players, purges what is past its period, logs the counts, and touches nothing younger" do
    idle = seen(new_player(1), 3.years + 1.second)
    never_seen = new_player(2, created_at: @now - 3.years - 1.second, updated_at: @now - 3.years - 1.second)
    active = seen(new_player(3), 3.years - 1.second)
    idle_moderator = seen(new_player(4, role: :moderator), 4.years)
    idle_banned = seen(new_player(5, banned_at: @now - 4.years), 4.years)
    handled = Accounts::Report.create!(reporter: active, reported: @player, reason: :cheating, handled_at: @now - 1.year - 1.second)
    open = Accounts::Report.create!(reporter: idle_moderator, reported: @player, reason: :cheating, created_at: @now - 5.years)
    dismissal = Accounts::ModerationAction.create!(kind: :dismissal, player: @player, staff: @moderator, created_at: @now - 1.year - 1.second)
    ban = Accounts::ModerationAction.create!(kind: :ban, player: idle_banned, staff: @moderator, reason: "Spam", created_at: @now - 5.years)

    log = run_job

    assert_includes log, "Accounts::ApplyRetentionJob: 2 idle accounts deleted, 1 reports purged, 1 moderation history rows purged"
    assert [ idle, never_seen ].all? { it.reload.deleted? }
    assert [ active, idle_moderator, idle_banned ].none? { it.reload.deleted? }
    assert_not_nil idle_banned.steam_id
    assert_not Accounts::Report.exists?(handled.id)
    assert Accounts::Report.exists?(open.id)
    assert_not Accounts::ModerationAction.exists?(dismissal.id)
    assert Accounts::ModerationAction.exists?(ban.id)
  end

  test "a second run finds nothing left; a late run purges all that came due meanwhile" do
    seen(new_player(1), 4.years)
    Accounts::ModerationAction.create!(kind: :dismissal, player: @player, staff: @moderator, created_at: @now - 3.years)
    Accounts::ModerationAction.create!(kind: :dismissal, player: @player, staff: @moderator, created_at: @now - 2.years)

    assert_includes run_job, "1 idle accounts deleted, 0 reports purged, 2 moderation history rows purged"
    assert_includes run_job, "0 idle accounts deleted, 0 reports purged, 0 moderation history rows purged"
  end

  test "more than a batch of each is all handled in one run" do
    stub_const(Accounts::ApplyRetentionJob, :IDLE_PLAYER_BATCH_SIZE, 1) do
      stub_const(Accounts::ApplyRetentionJob, :REPORT_BATCH_SIZE, 1) do
        stub_const(Accounts::ApplyRetentionJob, :MODERATION_PLAYER_BATCH_SIZE, 1) do
          [ new_player(1), new_player(2) ].each do |player|
            seen(player, 4.years)
            Accounts::Report.create!(reporter: player, reported: @player, reason: :other, handled_at: @now - 2.years)
          end
          [ @player, accounts_players(:banned) ].each do |player|
            Accounts::ModerationAction.create!(kind: :dismissal, player:, staff: @moderator, created_at: @now - 2.years)
          end

          assert_includes run_job, "2 idle accounts deleted, 2 reports purged, 2 moderation history rows purged"
        end
      end
    end
  end

  test "a player seen between selection and deletion is skipped silently" do
    returning = seen(new_player(1), 4.years)
    seen(new_player(2), 4.years)
    before_each_deletion { |player, now| player.update_columns(last_seen_at: now) if player.id == returning.id }

    assert_no_error_reported do
      assert_includes run_job, "1 idle accounts deleted"
    end
    assert_not_predicate returning.reload, :deleted?
  end

  test "a player whose deletion raises is reported, and the others are still deleted" do
    failing = seen(new_player(1), 4.years)
    other = seen(new_player(2), 4.years)
    before_each_deletion { |player, _now| raise "boom" if player.id == failing.id }

    assert_error_reported(RuntimeError) { run_job }
    assert_not_predicate failing.reload, :deleted?
    assert_predicate other.reload, :deleted?
  end
end

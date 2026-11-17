require "test_helper"
require_relative "../support/live_duels"

class DuelAbsenceJobTest < ActiveSupport::TestCase
  include ActiveJob::TestHelper
  include LiveDuels

  setup do
    @lea = accounts_players(:player)
    @hugo = accounts_players(:moderator)
    befriend(@lea, @hugo)
    complete_deck(@lea, "Lea")
    complete_deck(@hugo, "Hugo")
    @duel = start_duel(@lea, @hugo)
  end

  def lease(role, at) = Game::DuelSeat.where(duel_id: @duel.id, role:).update_all(present_until: at)

  test "an active duel with a seat whose lease has lapsed gets its connection slots pushed, and no board" do
    lease("opponent", 5.seconds.ago)

    assert_enqueued_with(job: DuelStreamJob, args: [ [ @duel.id ], { boards: false } ]) { DuelAbsenceJob.perform_now }
  end

  test "a held lease, a seat that never held one, or a finished duel pushes nothing" do
    lease("opponent", 5.seconds.from_now)
    lease("challenger", nil)
    assert_no_enqueued_jobs { DuelAbsenceJob.perform_now }

    lease("opponent", 5.seconds.ago)
    10.times { @duel = play_round(@duel) }
    assert_no_enqueued_jobs { DuelAbsenceJob.perform_now }
  end

  test "the pushes run on the duels queue, every 10 seconds in development and production" do
    assert_equal "duels", DuelAbsenceJob.new.queue_name
    recurring = YAML.safe_load(Rails.root.join("config/recurring.yml").read, aliases: true)

    %w[development production].each do |env|
      assert_equal({ "class" => "DuelAbsenceJob", "queue" => "duels", "schedule" => "every 10 seconds" }, recurring.dig(env, "sweep_duel_absence"), env)
    end
  end
end

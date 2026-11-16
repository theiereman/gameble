require "test_helper"
require_relative "../../support/game_packs"
require_relative "../../support/live_duels"

class Game::DuelDeadlinesTest < ActiveSupport::TestCase
  include ActiveJob::TestHelper
  include GamePacks
  include LiveDuels

  setup do
    travel_to Time.zone.now.change(usec: 0)
    @lea = accounts_players(:player)
    @hugo = accounts_players(:moderator)
    befriend(@lea, @hugo)
    complete_deck(@lea, "Lea")
    complete_deck(@hugo, "Hugo")
  end

  def challenge = Game::ChallengeFriend.new.call(player: @lea, friend: @hugo, deck_token: deck_token_of(@lea)).value!

  def accept(duel)
    Game::AcceptChallenge.new.call(player: @hugo, token: duel.token, deck_token: deck_token_of(@hugo), move_number: duel.move_number).value!
  end

  def current(duel) = Game::Duel.find(duel.id)

  def deadline_jobs = enqueued_jobs.select { it["job_class"] == "Game::DuelDeadlineJob" }

  def last_job = deadline_jobs.last

  def job_time(job) = Time.iso8601(job.fetch("scheduled_at"))

  def written(duel)
    [ current(duel).attributes, Game::DuelRound.where(duel_id: duel.id).order(:id).map(&:attributes),
      Game::DuelSeat.where(duel_id: duel.id).order(:id).map(&:attributes), Rails.configuration.event_store.read.count ]
  end

  def run_job(duel, move_number) = Game::DuelDeadlineJob.perform_now(duel.token, move_number)

  def sweep = Game::SweepDuelDeadlinesJob.perform_now

  def events(type) = Rails.configuration.event_store.read.of_type([ type ]).count

  def lease_ran_out(duel, role, ago: 61.seconds)
    Game::DuelSeat.where(duel_id: duel.id, role: role.to_s).update_all(present_until: Time.current - ago)
  end

  test "every hand-over sets the deadline of the next mover and enqueues its job two seconds later with the move number" do
    duel = challenge
    assert_equal Time.current + 60.seconds, current(duel).move_deadline_at
    assert_equal [ [ duel.token, 0 ], Time.current + 62.seconds ], [ last_job["arguments"], job_time(last_job) ]

    travel 5.seconds
    duel = accept(duel)
    assert_equal Time.current + 60.seconds, duel.move_deadline_at
    assert_equal [ [ duel.token, 1 ], Time.current + 62.seconds ], [ last_job["arguments"], job_time(last_job) ]

    travel 5.seconds
    duel = call_round(duel)
    assert_equal Time.current + 45.seconds, duel.move_deadline_at
    assert_equal [ [ duel.token, 2 ], Time.current + 47.seconds ], [ last_job["arguments"], job_time(last_job) ]

    travel 5.seconds
    duel = answer_round(duel)
    assert_equal Time.current + 60.seconds, duel.move_deadline_at
    assert_equal [ [ duel.token, 3 ], Time.current + 62.seconds ], [ last_job["arguments"], job_time(last_job) ]
    assert_equal "duels", Game::DuelDeadlineJob.new.queue_name
  end

  test "a job for an old move number does nothing" do
    duel = accept(challenge)
    call_round(duel)
    travel 2.minutes
    before = written(duel)

    run_job(duel, 1)

    assert_equal before, written(duel)
  end

  test "a job before the deadline does nothing" do
    duel = accept(challenge)
    travel 59.seconds
    before = written(duel)

    run_job(duel, 1)
    sweep

    assert_equal before, written(duel)
  end

  test "a real move just before the deadline wins over the job" do
    duel = accept(challenge)
    travel 59.seconds
    duel = call_round(duel)
    travel 4.seconds

    run_job(duel, 1)

    round = current(duel).rounds.sole
    assert_equal [ 2, false ], [ current(duel).move_number, round.caller_automatic ]
    assert_equal 1, events(Game::DuelRoundCalled)
  end

  test "a call whose time is up is played as the rules would, by the caller's seat, and marked on its round" do
    duel = accept(challenge)
    rules = rules_of(duel)
    expected = rules.automatic_call
    travel 63.seconds

    run_job(duel, 1)

    duel = current(duel)
    round = duel.rounds.sole
    assert_equal [ 2, rules.caller.to_s, expected.card.card_season_id, expected.stat.to_s, expected.direction.to_s, true, false ],
      [ duel.move_number, round.caller, round.caller_card_season_id, round.stat, round.direction, round.caller_automatic, round.answer_automatic ]
    assert_equal Time.current + 45.seconds, duel.move_deadline_at
    assert_equal 1, events(Game::DuelRoundCalled)
  end

  test "an answer whose time is up is played as the rules would and marked, then the next call gets its time" do
    duel = call_round(accept(challenge))
    rules = rules_of(current(duel))
    expected = rules.automatic_answer
    travel 48.seconds

    run_job(duel, 2)

    duel = current(duel)
    round = duel.rounds.sole
    assert_equal [ 3, expected.card_season_id, false, true ],
      [ duel.move_number, round.answer_card_season_id, round.caller_automatic, round.answer_automatic ]
    assert_equal Time.current + 60.seconds, duel.move_deadline_at
    assert_equal [ [ duel.token, 3 ] ], [ last_job["arguments"] ]
    assert_equal 1, events(Game::DuelRoundAnswered)
  end

  test "the answer of round 10 played automatically finishes the duel as an answer does" do
    duel = accept(challenge)
    9.times { duel = play_round(duel) }
    duel = call_round(duel)
    travel 48.seconds

    run_job(duel, current(duel).move_number)

    duel = current(duel)
    assert_equal [ "finished", true ], [ duel.state, duel.rounds.last.answer_automatic ]
    assert_equal 10, duel.rounds.size
    assert_not_nil duel.result
    assert_equal [ "left" ], Game::DuelSeat.where(duel_id: duel.id).pluck(:status).uniq
    assert_equal 1, events(Game::DuelFinished)
  end

  test "a challenge not accepted in time lapses for both: the seats leave and the event is written once" do
    duel = challenge
    travel 63.seconds

    run_job(duel, 0)

    duel = current(duel)
    assert_equal [ "lapsed", 1 ], [ duel.state, duel.move_number ]
    assert_equal [ "left", "left" ], Game::DuelSeat.where(duel_id: duel.id).order(:id).pluck(:status)
    assert_equal [ { duel_id: duel.id, challenger_id: @lea.id, opponent_id: @hugo.id } ],
      Rails.configuration.event_store.read.of_type([ Game::DuelChallengeLapsed ]).map(&:data)
    before = written(duel)
    run_job(duel, 0)
    sweep
    assert_equal before, written(duel)
  end

  test "the sweep catches a move whose job was lost, and a challenge nobody swept" do
    challenged = challenge
    travel 61.seconds
    assert_equal [ challenged.token ], Game::DuelsDue.call(Time.current)

    sweep

    assert_equal "lapsed", current(challenged).state
    assert_empty Game::DuelsDue.call(Time.current)

    other = start_duel(@lea, @hugo)
    travel 61.seconds
    sweep
    assert_equal [ 2, true ], [ current(other).move_number, current(other).rounds.sole.caller_automatic ]
  end

  test "the mover's reconnection deadline shortens the effective one, and a seat with no lease counts as present" do
    duel = accept(challenge)
    rules = rules_of(duel)
    travel 10.seconds
    sweep
    assert_equal 1, current(duel).move_number

    lease_ran_out(duel, rules.answerer)
    sweep
    assert_equal 1, current(duel).move_number, "the answerer is not the one who must act"

    lease_ran_out(duel, rules.caller, ago: 59.seconds)
    sweep
    assert_equal 1, current(duel).move_number, "less than a minute since the lease ran out"

    lease_ran_out(duel, rules.caller)
    sweep
    assert_equal [ 2, true ], [ current(duel).move_number, current(duel).rounds.sole.caller_automatic ]
  end

  test "a lease that still holds leaves the deadline as it is" do
    duel = accept(challenge)
    lease_ran_out(duel, rules_of(duel).caller, ago: -30.seconds)

    clock = Game::DuelClock.new(current(duel), current(duel).seats.to_a, rules_of(current(duel)))

    assert_equal current(duel).move_deadline_at, clock.deadline
  end
end

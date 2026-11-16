require "test_helper"
require_relative "../support/live_duels"

# Each change of a started duel reaches its seats: one job per transaction, enqueued once it commits, named by the duel.
class DuelStreamTest < ActiveSupport::TestCase
  include ActiveJob::TestHelper
  include LiveDuels

  setup do
    @lea = accounts_players(:player)
    @hugo = accounts_players(:moderator)
    befriend(@lea, @hugo)
    complete_deck(@lea, "Lea")
    complete_deck(@hugo, "Hugo")
  end

  def duel_ids = enqueued_jobs.select { it[:job] == DuelStreamJob }.flat_map { ActiveJob::Arguments.deserialize(it[:args]).first }

  test "a seat's stream is named by its key and the locale, with no database id" do
    assert_equal [ "duel-seat", "abc", "fr" ], DuelStream.streamables("abc", :fr)
  end

  test "every change of a started duel is heard" do
    expected = %w[DuelChallengeAccepted DuelRoundCalled DuelRoundAnswered DuelFinished].map { "Game::#{it}" }

    assert_equal expected, DuelStream::EVENTS.map(&:name)
  end

  test "an acceptance, a call and an answer each enqueue one job for their duel after the commit; a challenge and a refusal none" do
    duel = nil
    assert_no_enqueued_jobs(only: DuelStreamJob) do
      duel = Game::ChallengeFriend.new.call(player: @lea, friend: @hugo, deck_token: deck_token_of(@lea)).value!
    end

    assert_enqueued_jobs(1, only: DuelStreamJob) do
      Game::AcceptChallenge.new.call(player: @hugo, token: duel.token, deck_token: deck_token_of(@hugo), move_number: 0).value!
    end
    assert_equal [ duel.id ], duel_ids

    clear_enqueued_jobs
    assert_enqueued_jobs(1, only: DuelStreamJob) { call_round(duel) }
    assert_enqueued_jobs(1, only: DuelStreamJob) { answer_round(duel) }
    assert_equal [ duel.id, duel.id ], duel_ids

    clear_enqueued_jobs
    assert_no_enqueued_jobs(only: DuelStreamJob) do
      Game::CallRound.new.call(player: @lea, token: duel.token, move_number: 0, card: 1, stat: "rating", direction: "high")
    end
  end

  test "nothing is enqueued when the transaction rolls back" do
    duel = Game::ChallengeFriend.new.call(player: @lea, friend: @hugo, deck_token: deck_token_of(@lea)).value!

    ActiveRecord::Base.transaction(requires_new: true) do
      Game::AcceptChallenge.new.call(player: @hugo, token: duel.token, deck_token: deck_token_of(@hugo), move_number: 0).value!
      raise ActiveRecord::Rollback
    end

    assert_empty duel_ids
  end
end

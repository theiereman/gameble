require "test_helper"
require_relative "../../support/live_duels"

# A duel whose opponent is banned, deleted or made private finishes: the removed player's moves are played by the game,
# a deleted player's seat is emptied of the player once the duel has ended, and a challenge to them lapses.
class Game::RemovedPlayerDuelsTest < ActiveSupport::TestCase
  include ActiveJob::TestHelper
  include LiveDuels

  setup do
    travel_to Time.zone.now.change(usec: 0)
    @lea = accounts_players(:player)
    @hugo = accounts_players(:moderator)
    @admin = accounts_players(:administrator)
    befriend(@lea, @hugo)
    complete_deck(@lea, "Lea")
    complete_deck(@hugo, "Hugo")
  end

  def ban(player) = Accounts::BanPlayer.new.call(staff: @admin, player:, reason: "Cheating").value!

  def delete(player) = Accounts::DeletePlayer.new.call(player: Accounts::Player.find(player.id), allow_banned: true).value!

  def private_profile(player) = Accounts::SetVisibility.new.call(player: Accounts::Player.find(player.id), visibility: "private").value!

  def current(duel) = Game::Duel.find(duel.id)

  def seat(duel, role) = Game::DuelSeat.find_by!(duel_id: duel.id, role: role.to_s)

  def rounds(duel) = Game::DuelRound.where(duel_id: duel.id).order(:number)

  def events(type) = Rails.configuration.event_store.read.of_type([ type ]).to_a

  def played_rounds(duel, count) = count.times.reduce(duel) { |played, _| play_round(played) }

  # Léa plays her moves as the rules would; Hugo's time runs out and the sweep plays his.
  def play_out(duel)
    40.times do
      duel = current(duel)
      return duel if duel.state == "finished"

      rules = rules_of(duel)
      mover = rules.pending ? rules.answerer : rules.caller
      next(rules.pending ? answer_round(duel) : call_round(duel)) if mover == :challenger

      travel 61.seconds
      Game::SweepDuelDeadlinesJob.perform_now
    end
    flunk "the duel did not finish"
  end

  test "a banned player's duel goes on to its result, their moves played automatically, and the seat keeps its player" do
    duel = played_rounds(start_duel(@lea, @hugo), 3)
    ban(@hugo)

    assert_equal "active", current(duel).state
    finished = play_out(duel)

    assert_equal 10, rounds(finished).size
    assert_equal [ "left", "left" ], [ seat(finished, :challenger).status, seat(finished, :opponent).status ]
    assert_equal @hugo.id, seat(finished, :opponent).player_id
    assert rounds(finished).where("number > 3").all? { it.caller == "opponent" ? it.caller_automatic : it.answer_automatic }
    assert rounds(finished).where("number > 3").none? { it.caller == "challenger" ? it.caller_automatic : it.answer_automatic }
    assert_equal 1, events("Game::DuelFinished").size
  end

  test "a banned player's page no longer renews the lease of their seat" do
    duel = start_duel(@lea, @hugo)
    ban(@hugo)

    Game::NoteDuelPresence.new.call(stream_key: seat(duel, :opponent).stream_key)
    assert_nil seat(duel, :opponent).present_until
    Game::NoteDuelPresence.new.call(stream_key: seat(duel, :challenger).stream_key)
    assert_not_nil seat(duel, :challenger).present_until
  end

  test "a deleted player's duel goes on, and the finishing move empties their seat after publishing the finish for them" do
    duel = played_rounds(start_duel(@lea, @hugo), 3)
    delete(@hugo)

    assert_equal [ "active", @hugo.id, "seated" ], [ current(duel).state, seat(duel, :opponent).player_id, seat(duel, :opponent).status ]
    finished = play_out(duel)

    assert_equal [ nil, "left" ], [ seat(finished, :opponent).player_id, seat(finished, :opponent).status ]
    assert_equal @lea.id, seat(finished, :challenger).player_id
    assert_equal 10, rounds(finished).size
    assert_equal [ @hugo.id ], events("Game::DuelFinished").map { it.data[:opponent_id] }
    assert_not_nil current(finished).result
  end

  test "deleting a player after a duel empties the player of their finished seats and keeps the result" do
    finished = played_rounds(start_duel(@lea, @hugo), 10)
    result = [ finished.result, finished.challenger_score, finished.opponent_score ]

    delete(@hugo)

    assert_nil seat(finished, :opponent).player_id
    assert_equal @lea.id, seat(finished, :challenger).player_id
    assert_equal result, [ current(finished).result, current(finished).challenger_score, current(finished).opponent_score ]
  end

  test "deleting a player empties the seats of every ended duel, including a refused challenge" do
    refused = Game::ChallengeFriend.new.call(player: @lea, friend: @hugo, deck_token: deck_token_of(@lea)).value!
    Game::RefuseChallenge.new.call(player: @hugo, token: refused.token).value!

    delete(@hugo)

    assert_equal [ "left", nil ], [ seat(refused, :opponent).status, seat(refused, :opponent).player_id ]
    assert_equal @lea.id, seat(refused, :challenger).player_id
  end

  test "a player who goes private mid-duel keeps playing, and the duel finishes with both players seated" do
    duel = played_rounds(start_duel(@lea, @hugo), 3)
    private_profile(@hugo)

    finished = played_rounds(duel, 7)

    assert_equal "finished", current(finished).state
    assert_equal [ @lea.id, @hugo.id ], [ seat(finished, :challenger).player_id, seat(finished, :opponent).player_id ]
    assert_not rounds(finished).any? { it.caller_automatic || it.answer_automatic }
  end

  test "a player who goes private mid-duel and leaves has their moves played, and the duel finishes" do
    duel = played_rounds(start_duel(@lea, @hugo), 3)
    private_profile(@hugo)

    assert_equal "finished", play_out(duel).state
  end

  test "a received challenge lapses with the deletion of the invited player, whose seat is emptied, and tells the challenger" do
    duel = Game::ChallengeFriend.new.call(player: @lea, friend: @hugo, deck_token: deck_token_of(@lea)).value!
    clear_enqueued_jobs

    delete(@hugo)

    lapsed = current(duel)
    assert_equal [ "lapsed", 1 ], [ lapsed.state, lapsed.move_number ]
    assert_not_nil lapsed.ended_at
    assert_equal [ "left", nil ], [ seat(duel, :opponent).status, seat(duel, :opponent).player_id ]
    assert_equal [ "left", @lea.id ], [ seat(duel, :challenger).status, seat(duel, :challenger).player_id ]
    assert_equal [ { player_id: @lea.id, topic: "duels", duel_id: duel.id, kind: "lapsed", role: "challenger" } ], duel_notices
    assert_equal :not_due, Game::LapseChallenge.new.call(player: @lea, token: duel.token, move_number: 0).failure
  end

  test "a challenge from a banned player cannot be accepted and lapses at its deadline" do
    duel = Game::ChallengeFriend.new.call(player: @lea, friend: @hugo, deck_token: deck_token_of(@lea)).value!
    ban(@lea)

    refusal = Game::AcceptChallenge.new.call(player: @hugo, token: duel.token, deck_token: deck_token_of(@hugo), move_number: duel.move_number)
    assert_equal :not_a_friend, refusal.failure
    assert_equal "challenged", current(duel).state

    travel 61.seconds
    Game::SweepDuelDeadlinesJob.perform_now

    assert_equal "lapsed", current(duel).state
    assert_equal [ "left", "left" ], [ seat(duel, :challenger).status, seat(duel, :opponent).status ]
  end

  test "a challenge from a player gone private cannot be accepted and lapses at its deadline" do
    duel = Game::ChallengeFriend.new.call(player: @lea, friend: @hugo, deck_token: deck_token_of(@lea)).value!
    private_profile(@lea)

    refusal = Game::AcceptChallenge.new.call(player: @hugo, token: duel.token, deck_token: deck_token_of(@hugo), move_number: duel.move_number)
    assert_equal :friend_duels_closed, refusal.failure

    travel 61.seconds
    Game::SweepDuelDeadlinesJob.perform_now

    assert_equal "lapsed", current(duel).state
  end

  test "a challenge from a deleted player lapses at its deadline and empties their seat" do
    duel = Game::ChallengeFriend.new.call(player: @lea, friend: @hugo, deck_token: deck_token_of(@lea)).value!
    delete(@lea)

    assert_equal "challenged", current(duel).state
    travel 61.seconds
    Game::SweepDuelDeadlinesJob.perform_now

    assert_equal "lapsed", current(duel).state
    assert_equal [ nil, @hugo.id ], [ seat(duel, :challenger).player_id, seat(duel, :opponent).player_id ]
  end

  def duel_notices
    enqueued_jobs.select { it[:job] == PlayerStreamJob }.flat_map { ActiveJob::Arguments.deserialize(it[:args]).first }
      .select { it[:topic] == "duels" }
  end
end

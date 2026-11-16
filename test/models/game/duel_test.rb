require "test_helper"
require_relative "../../support/duels"

# What the database refuses of a duel, its seats and its rounds even when operations are bypassed, and how a duel row
# reads its frozen decks back.
class Game::DuelTest < ActiveSupport::TestCase
  include Duels

  setup do
    @duel = active_duel.tap(&:save!)
    @portal = catalog_card_seasons(:portal_one).id
  end

  def refused(error = ActiveRecord::CheckViolation, &block)
    assert_raises(error) { ActiveRecord::Base.transaction(requires_new: true, &block) }
  end

  def change(**columns) = Game::Duel.where(id: @duel.id).update_all(columns)

  def seat(duel: @duel, role: "challenger", status: "seated", player: accounts_players(:player))
    Game::DuelSeat.create!(duel:, role:, status:, player_id: player&.id)
  end

  def round(**columns)
    Game::DuelRound.create!({ duel: @duel, number: 1, caller: "challenger", caller_card_season_id: @portal, stat: "rating",
      direction: "high", called_at: Time.current }.merge(columns))
  end

  test "a duel's state, first caller, result and capsule come from their lists" do
    refused { change(state: "paused") }
    refused { change(first_caller: "referee") }
    refused { change(state: "finished", ended_at: Time.current, result: "forfeit") }
    refused { change(state: "finished", ended_at: Time.current, result: "draw", capsule: "jackpot") }

    assert_equal 1, change(state: "finished", ended_at: Time.current, result: "draw", capsule: "already_won_today")
  end

  test "only a started duel holds its first caller, decks and draws, only an ended one its end, only a finished one its result and capsule" do
    refused { Game::Duel.create!(state: "active") }
    refused { change(opponent_draw_order: nil) }
    refused { change(state: "challenged") }
    refused { change(ended_at: Time.current) }
    refused { change(state: "cancelled") }
    refused { change(state: "finished", ended_at: Time.current) }
    refused { change(result: "challenger") }
    refused { change(capsule: "granted") }

    assert Game::Duel.create!(state: "refused", ended_at: Time.current).persisted?
    assert Game::Duel.create!(challenger_cards: []).persisted?
  end

  test "scores run 0 to 10 and sum to 10 at most; margins and the move number are never negative" do
    refused { change(challenger_score: 11) }
    refused { change(opponent_score: -1) }
    refused { change(challenger_score: 6, opponent_score: 5) }
    refused { change(challenger_margin: -0.1) }
    refused { change(move_number: -1) }

    assert_equal 1, change(challenger_score: 6, opponent_score: 4, challenger_margin: 999.9, move_number: 20)
  end

  test "a seat is the challenger or the opponent once a duel, invited only as the opponent, and without a player only once left" do
    refused { seat(role: "referee") }
    refused { seat(status: "waiting") }
    refused { seat(status: "invited") }
    refused { seat(player: nil) }
    seat
    refused(ActiveRecord::RecordNotUnique) { seat(player: accounts_players(:moderator)) }

    assert seat(role: "opponent", status: "invited", player: accounts_players(:moderator)).persisted?
    assert seat(duel: Game::Duel.create!, status: "left", player: nil).persisted?
  end

  test "a player is seated at one duel and invited to one duel at most" do
    seat
    seat(role: "opponent", status: "invited", player: accounts_players(:moderator))
    other = Game::Duel.create!

    refused(ActiveRecord::RecordNotUnique) { seat(duel: other) }
    refused(ActiveRecord::RecordNotUnique) { seat(duel: other, role: "opponent", status: "invited", player: accounts_players(:moderator)) }
    assert seat(duel: other, role: "opponent", status: "invited").persisted?
    assert seat(duel: other, status: "seated", player: accounts_players(:moderator)).persisted?
    assert seat(duel: Game::Duel.create!, status: "left").persisted?
  end

  test "a round is numbered 1 to 10 once a duel, its call from the lists, answered with a card, and won only once answered" do
    refused { round(number: 0) }
    refused { round(number: 11) }
    refused { round(caller: "referee") }
    refused { round(stat: "price") }
    refused { round(direction: "sideways") }
    refused { round(answered_at: Time.current) }
    refused { round(answer_card_season_id: @portal) }
    refused { round(winner: "challenger") }
    refused { round(answer_card_season_id: @portal, answered_at: Time.current, winner: "referee") }

    round(answer_card_season_id: @portal, answered_at: Time.current, winner: "opponent", decided_on_value: true)
    refused(ActiveRecord::RecordNotUnique) { round }
    assert round(number: 10).persisted?
  end

  test "a duel reads back its frozen decks and draw orders, and has none before it starts" do
    duel = Game::Duel.find(@duel.id)

    assert duel.started?
    assert_equal [ duel_deck(1001), duel_deck(2001) ], [ duel.cards(:challenger), duel.cards(:opponent) ]
    assert_equal ids(duel_deck(1001)).reverse, duel.draw_order(:challenger)
    assert_predicate duel.cards(:challenger).first, :frozen?
    assert_predicate duel.cards(:challenger).first.stats, :frozen?

    challenge = Game::Duel.create!
    assert_not challenge.started?
    assert_equal [ [], [] ], [ challenge.cards(:opponent), challenge.draw_order(:opponent) ]
    assert_equal 24, challenge.token.size
  end
end

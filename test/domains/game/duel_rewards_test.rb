require "test_helper"
require_relative "../../support/game_packs"
require_relative "../../support/live_duels"

# During the alpha a duel grants nothing: the finishing move of a real win, with no automatic move, draws no duel
# capsule and runs no achievement job, and a finish by an automatic move records no capsule case.
class Game::DuelRewardsTest < ActiveSupport::TestCase
  include ActiveJob::TestHelper
  include GamePacks
  include LiveDuels

  setup do
    @lea = accounts_players(:player)
    @hugo = accounts_players(:moderator)
    befriend(@lea, @hugo)
    complete_deck(@lea, "Lea")
    complete_deck(@hugo, "Hugo")
    Game::DeckCard.where(deck_id: Game::Deck.where(player_id: @lea.id).select(:id)).pluck(:card_season_id)
      .each { set_percentiles(it, **Game::DuelStat::STATS.index_with { 100 }) }
  end

  def duel_called_first_by_lea
    duel = start_duel(@lea, @hugo)
    Game::Duel.where(id: duel.id).update_all(first_caller: "challenger")
    Game::Duel.find(duel.id)
  end

  test "a real win of the day's first duel draws no capsule and runs no achievement job" do
    duel = duel_called_first_by_lea

    assert_no_enqueued_jobs only: Game::GrantAchievementsJob do
      10.times { play_round(duel) }
    end

    duel = Game::Duel.find(duel.id)
    assert_equal [ "finished", "challenger", nil ], [ duel.state, duel.result, duel.capsule ]
    assert duel.rounds.none? { it.caller_automatic || it.answer_automatic }
    assert_empty Game::Pack.where(player_id: [ @lea.id, @hugo.id ], kind: "duel")
  end

  test "a duel finished by an automatic move records no capsule case" do
    duel = duel_called_first_by_lea
    9.times { play_round(duel) }
    duel = Game::Duel.find(call_round(duel).id)
    travel 61.seconds
    rules = rules_of(duel)
    Game::PlayAutomaticMove.new.call(player: seat_player(duel, rules.answerer), token: duel.token, move_number: duel.move_number).value!

    duel = Game::Duel.find(duel.id)
    assert_equal [ "finished", nil ], [ duel.state, duel.capsule ]
    assert_empty Game::Pack.where(kind: "duel")
  end
end

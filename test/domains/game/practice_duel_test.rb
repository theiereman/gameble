require "test_helper"
require_relative "../../support/game_packs"
require_relative "../../support/live_duels"

# A training duel against the bot: it holds a deck drawn from the catalog, plays its own moves, and counts for nothing.
class Game::PracticeDuelTest < ActiveSupport::TestCase
  include GamePacks
  include LiveDuels

  setup do
    @lea = accounts_players(:player)
    complete_deck(@lea, "Lea")
    complete_deck(accounts_players(:moderator), "Catalog")
  end

  def start = Game::StartPracticeDuel.new.call(player: @lea, deck_token: deck_token_of(@lea))

  def bot_move(duel) = Game::PracticeBotJob.perform_now(duel.token, Game::Duel.find(duel.id).move_number)

  test "a practice duel starts active against a bot with its own twelve catalog cards" do
    duel = start.value!

    assert duel.practice
    assert_equal "active", duel.state
    bot = Accounts::Player.find_by!(bot_of_id: @lea.id)
    assert_equal [ @lea.id, bot.id ], duel.seats.order(:id).map(&:player_id)
    assert_equal 12, duel.opponent_cards.size
    assert_equal 12, duel.opponent_cards.map { it["card_id"] }.uniq.size
    assert_equal 1, Accounts::Player.where(bot_of_id: @lea.id).count
  end

  test "a second practice duel reuses the bot, and none starts while a duel is in progress" do
    first = start.value!

    assert_equal :duel_in_progress, start.failure

    Game::DuelSeat.where(duel_id: first.id).update_all(status: "left")
    assert start.success?
    assert_equal 1, Accounts::Player.where(bot_of_id: @lea.id).count
  end

  test "the bot plays its calls and its answers, and a draft cannot practise" do
    duel = start.value!
    Game::Duel.where(id: duel.id).update_all(first_caller: "opponent")
    bot_move(duel)

    assert_equal 1, Game::Duel.find(duel.id).rounds.count
    assert Game::Duel.find(duel.id).rules.pending

    draft = Game::CreateDeck.new.call(player: accounts_players(:moderator), name: "Draft").value!
    assert_equal :deck_not_ready, Game::StartPracticeDuel.new.call(player: accounts_players(:moderator), deck_token: draft.token).failure
  end

  test "a practice duel played to the end counts in no record or history and gives no capsule" do
    duel = start.value!
    20.times do
      duel = Game::Duel.find(duel.id)
      break if duel.state == "finished"

      rules = rules_of(duel)
      mover = rules.pending ? rules.answerer : rules.caller
      if mover == :opponent then bot_move(duel)
      elsif rules.pending then answer_round(duel)
      else call_round(duel)
      end
    end
    duel = Game::Duel.find(duel.id)

    assert_equal "finished", duel.state
    assert_nil duel.capsule
    assert_equal Game::DuelRecord::NONE, Game::DuelRecord.call(@lea)
    assert_empty Game::RecentDuels.call(@lea)
    assert_equal 0, Game::Pack.where(player_id: @lea.id, kind: "duel").count
  end

  test "a stale bot job plays nothing" do
    duel = start.value!
    Game::Duel.where(id: duel.id).update_all(first_caller: "challenger")

    Game::PracticeBotJob.perform_now(duel.token, 99)
    bot_move(duel)

    assert_empty Game::Duel.find(duel.id).rounds
  end
end

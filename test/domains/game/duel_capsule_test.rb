require "test_helper"
require_relative "../../support/duels"
require_relative "../../support/game_packs"
require_relative "../../support/live_duels"

# The first real win of the UTC day gives a duel capsule, drawn by the finishing move for the winner alone, in its
# transaction; a win with an automatic move of the winner, a win after one that day, a loss and a draw give none.
class Game::DuelCapsuleTest < ActiveSupport::TestCase
  include Duels
  include GamePacks
  include LiveDuels

  setup do
    @lea = accounts_players(:player)
    @hugo = accounts_players(:moderator)
    befriend(@lea, @hugo)
    complete_deck(@lea, "Lea")
    complete_deck(@hugo, "Hugo")
    lea_cards = Game::DeckCard.where(deck_id: Game::Deck.where(player_id: @lea.id).select(:id)).pluck(:card_season_id)
    lea_cards.each { set_percentiles(it, **Game::DuelStat::STATS.index_with { 100 }) }
  end

  def duel_packs(player) = Game::Pack.where(player_id: player.id, kind: "duel")

  def current(duel) = Game::Duel.find(duel.id)

  def duel_between(first_caller: "challenger")
    duel = start_duel(@lea, @hugo)
    Game::Duel.where(id: duel.id).update_all(first_caller:)
    current(duel)
  end

  def play_to_the_end(duel) = 10.times { duel = play_round(duel) }

  # The mover's time runs out and the game plays the move.
  def play_for_the_mover(duel)
    duel = current(duel)
    rules = rules_of(duel)
    mover = seat_player(duel, rules.pending ? rules.answerer : rules.caller)
    travel 61.seconds
    Game::PlayAutomaticMove.new.call(player: mover, token: duel.token, move_number: duel.move_number).value!
  end

  test "the winner's finishing move draws one duel capsule of three cards in the special reserve and records it" do
    duel = duel_between
    play_to_the_end(duel)

    finished = current(duel)
    assert_equal [ "challenger", "granted" ], [ finished.result, finished.capsule ]
    pack = duel_packs(@lea).sole
    assert_equal [ 3, Time.current.utc.to_date, finished.ended_at.utc.to_date, Catalog::PublishedSeason.call.id ],
      [ pack.card_season_ids.size, pack.duel_day, pack.duel_day, pack.season_id ]
    assert_nil pack.opened_at
    assert_equal 1, Game::Reserve.counts(@lea.id).special
    assert_equal 0, Game::Reserve.counts(@lea.id).standard
    assert_equal "duel", Game::Reserve.counts(@lea.id).next_special_kind
    assert_equal [ "special" ], [ Game::Reserve.name_of(pack.kind) ]
  end

  test "the loser gets nothing and the finishing move still writes its one event" do
    play_to_the_end(duel_between)

    assert_empty duel_packs(@hugo)
    assert_equal 1, Rails.configuration.event_store.read.of_type([ Game::DuelFinished ]).count
    assert_equal 0, Rails.configuration.event_store.read.of_type([ Game::PackOpened, Game::DailyBonusCollected ]).count
  end

  test "a draw gives nothing and records no case" do
    same = ->(first_id) { Array.new(12) { |index| duel_card(first_id + index, number: index + 1) } }
    duel = active_duel(challenger: same.(1001), opponent: same.(2001))
    10.times { play_automatic_round(duel) }
    rules = Game::DuelRules.new(duel, duel.rounds.to_a)
    seats = { challenger: Game::DuelSeat.new(player_id: @lea.id), opponent: Game::DuelSeat.new(player_id: @hugo.id) }

    assert_equal :draw, rules.result
    assert_nil Game::DuelCapsule.award(rules, seats, Time.current)
    assert_equal 0, Game::Pack.where(kind: "duel").count
  end

  test "a win after the winner's automatic move gives no capsule and says so" do
    duel = duel_between
    duel = answer_round(play_for_the_mover(duel))
    9.times { duel = play_round(duel) }

    finished = current(duel)
    assert_equal [ "finished", "challenger", "automatic_move" ], [ finished.state, finished.result, finished.capsule ]
    assert_empty duel_packs(@lea)
  end

  test "an automatic move of the loser alone leaves the winner's capsule" do
    duel = duel_between
    duel = call_round(duel)
    play_for_the_mover(duel)
    duel = current(duel)
    9.times { duel = play_round(duel) }

    finished = current(duel)
    assert_equal [ "challenger", "granted" ], [ finished.result, finished.capsule ]
    assert_equal 1, duel_packs(@lea).count
  end

  test "the second win of the same UTC day gives none and says it was won today, the next day gives one again" do
    travel_to Time.utc(2026, 11, 17, 22, 0)
    play_to_the_end(duel_between)
    travel_to Time.utc(2026, 11, 17, 23, 59)
    second = duel_between
    play_to_the_end(second)

    assert_equal "already_won_today", current(second).capsule
    assert_equal [ Date.new(2026, 11, 17) ], duel_packs(@lea).pluck(:duel_day)

    travel_to Time.utc(2026, 11, 18, 0, 1)
    third = duel_between
    play_to_the_end(third)

    assert_equal "granted", current(third).capsule
    assert_equal [ Date.new(2026, 11, 17), Date.new(2026, 11, 18) ], duel_packs(@lea).order(:duel_day).pluck(:duel_day)
  end

  test "the day is the UTC day the duel ends, whatever the winner's local hour" do
    travel_to Time.utc(2026, 11, 17, 23, 30)
    duel = duel_between
    travel_to Time.utc(2026, 11, 18, 0, 10)
    play_to_the_end(duel)

    assert_equal [ Date.new(2026, 11, 18) ], duel_packs(@lea).pluck(:duel_day)
  end

  test "a winner who was banned or deleted before the finish gets no capsule and no case" do
    strong = Array.new(12) { |index| duel_card(1001 + index, number: index + 1, **Game::DuelStat::STATS.index_with { 90 }) }
    duel = active_duel(challenger: strong, opponent: Array.new(12) { |index| duel_card(2001 + index, number: index + 1) })
    10.times do
      call = Game::DuelRules.new(duel, duel.rounds.to_a).automatic_call
      lock_call(duel, call.card.card_season_id, call.stat, call.direction)
      answer_call(duel, Game::DuelRules.new(duel, duel.rounds.to_a).automatic_answer.card_season_id)
    end
    rules = Game::DuelRules.new(duel, duel.rounds.to_a)
    seats = { challenger: Game::DuelSeat.new(player_id: @lea.id), opponent: Game::DuelSeat.new(player_id: @hugo.id) }

    assert_equal :challenger, rules.result
    assert_equal "granted", Game::DuelCapsule.award(rules, seats, Time.current)
    duel_packs(@lea).delete_all

    @lea.update!(banned_at: Time.current)
    assert_nil Game::DuelCapsule.award(rules, seats, Time.current)
    @lea.update!(banned_at: nil, deleted_at: Time.current, steam_id: nil)
    assert_nil Game::DuelCapsule.award(rules, seats, Time.current)
    assert_empty duel_packs(@lea)
  end

  test "the unique index refuses a second duel capsule of the day whatever the operation does, and the grant reports it" do
    create_pack(@lea, kind: :duel, available_at: Time.current)

    assert_raises(ActiveRecord::RecordNotUnique) { create_pack(@lea, kind: :duel, available_at: Time.current) }
    pool = Game::DrawPool.current
    assert_not Game::DuelCapsule.send(:grant, @lea, pool, Time.current, SecureRandom)
    assert_equal 1, duel_packs(@lea).count
    assert Game::DuelCapsule.send(:grant, @hugo, pool, Time.current, SecureRandom)
    assert Game::DuelCapsule.send(:grant, @lea, pool, 1.day.from_now, SecureRandom)
  end

  test "the checks refuse an unknown kind, a duel capsule of the wrong size and a duel day on any other kind" do
    assert_raises(ActiveRecord::StatementInvalid) do
      Game::Pack.insert!(Game::Pack.row(player_id: @lea.id, kind: :mystery, season_id: catalog_seasons(:one).id,
        card_season_ids: [ catalog_card_seasons(:portal_one).id ] * 3, available_at: Time.current))
    end
    assert_raises(ActiveRecord::StatementInvalid) { create_pack(@lea, kind: :duel, cards: [ catalog_card_seasons(:portal_one).id ] * 5) }
    assert_raises(ActiveRecord::StatementInvalid) { create_pack(@lea, kind: :bonus, duel_day: Date.current) }
    assert_raises(ActiveRecord::StatementInvalid) { create_pack(@lea, kind: :duel, duel_day: nil) }
  end
end

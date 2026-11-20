require_relative "duels"

# Saved finished duels of every kind the duels balance reads: live duels between named deck recipes with their calls, a
# forfeit, a duel under the previous rules, practice duels by bot archetype, and duels that never finished.
module BalanceDuels
  include Duels

  def deck(first_id, **percentiles) = Array.new(12) { duel_card(first_id + it, **percentiles) }

  def coverage_deck(first_id)
    strong = Game::DuelStat::STATS.each_with_index.flat_map do |stat, index|
      [ duel_card(first_id + (2 * index), stat => 95), duel_card(first_id + (2 * index) + 1, stat => 5) ]
    end
    strong + [ duel_card(first_id + 10), duel_card(first_id + 11) ]
  end

  def trumps_deck(first_id) = Array.new(12) { duel_card(first_id + it, Game::DuelStat::STATS[it % 5] => 99) }

  # Each call is [stat, direction] or [stat, direction, automatic].
  def finished_duel(challenger:, opponent:, result:, first_caller: "challenger", scores: [ 6, 4 ], calls: [],
    rules_version: Game::DuelRules::VERSION, **attributes)
    duel = active_duel(challenger:, opponent:, first_caller:)
    duel.assign_attributes(state: "finished", result:, ended_at: Time.current, challenger_score: scores.first,
      opponent_score: scores.last, rules_version:, **attributes)
    duel.save!
    calls.each.with_index(1) do |(stat, direction, automatic), number|
      duel.rounds.create!(number:, caller: first_caller, caller_card_season_id: catalog_card_seasons(:portal_one).id,
        stat: stat.to_s, direction: direction.to_s, caller_automatic: automatic == true, called_at: Time.current)
    end
    duel
  end

  def play_balance_duels
    finished_duel(challenger: deck(1001, rating: 95), opponent: deck(1101), result: "challenger",
      calls: [ %i[rating high], %i[rating high] ])
    finished_duel(challenger: coverage_deck(1201), opponent: deck(1301, rating: 95), first_caller: "opponent",
      result: "challenger", scores: [ 5, 5 ], calls: [ [ :popularity, :low, true ], %i[release high] ])
    finished_duel(challenger: deck(1401, popularity: 95), opponent: deck(1501), result: "draw", scores: [ 5, 5 ],
      calls: [ %i[discovery low] ])
    finished_duel(challenger: deck(1601, rating: 95), opponent: coverage_deck(1701), result: "challenger",
      forfeited_by: "opponent", scores: [ 2, 1 ], calls: [ [ :circulation, :high, true ] ])
    finished_duel(challenger: deck(1801), opponent: deck(1901), first_caller: "opponent", result: "opponent",
      scores: [ 4, 6 ], rules_version: Game::DuelRules::VERSION - 1, calls: [ %i[rating low] ])

    finished_duel(challenger: trumps_deck(2001), opponent: trumps_deck(2101), practice: true, bot_archetype: "rating",
      result: "opponent", scores: [ 4, 6 ], calls: [ %i[popularity high] ])
    finished_duel(challenger: trumps_deck(2201), opponent: trumps_deck(2301), practice: true, bot_archetype: "rating",
      result: "challenger", calls: [ %i[popularity high] ])
    finished_duel(challenger: trumps_deck(2401), opponent: trumps_deck(2501), practice: true, result: "draw",
      scores: [ 5, 5 ], calls: [ %i[rating low] ])

    active_duel.save!
    Game::Duel.create!(state: "challenged")
    Game::Duel.create!(state: "cancelled", ended_at: Time.current)
  end
end

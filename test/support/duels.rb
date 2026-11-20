# Builds duels in memory: frozen cards of chosen percentiles, two twelve-card decks, an active duel between them, and
# the calls locked and answered as its rounds.
module Duels
  # The value a card holds on a stat a test gives a percentile but no value.
  VALUES = { popularity: 50_000, rating: 80, release: Date.new(2015, 6, 1), discovery: Time.utc(2026, 1, 1, 12), circulation: 40 }.freeze

  # A card at 50 on each stat unless given, with no value on a stat given nil; its median distances follow its
  # percentiles unless given.
  def duel_card(card_season_id, number: 1, values: {}, distances: {}, **percentiles)
    stats = Game::DuelStat::STATS.index_with do |stat|
      percentile = percentiles.fetch(stat, 50)
      next Game::DuelCard::Stat.new(value: nil, percentile: nil, median_distance: nil) if percentile.nil?

      Game::DuelCard::Stat.new(value: values.fetch(stat, VALUES.fetch(stat)), percentile: BigDecimal(percentile.to_s),
        median_distance: distances.fetch(stat, (percentile - 50).abs.to_f))
    end
    Game::DuelCard.new(card_season_id:, card_id: card_season_id + 100_000, number:, rarity: 1, stats:)
  end

  # Twelve cards numbered from `first_id` in their fixed order, their percentiles spread from 0 to 100.
  def duel_deck(first_id)
    Array.new(12) do |index|
      percentiles = Game::DuelStat::STATS.each_with_index.to_h { |stat, place| [ stat, (first_id + (index * 37) + (place * 23)) % 101 ] }
      duel_card(first_id + index, number: index + 1, **percentiles)
    end
  end

  # An unsaved active duel the challenger calls first, each deck drawn last card first.
  def active_duel(challenger: duel_deck(1001), opponent: duel_deck(2001), first_caller: "challenger")
    Game::Duel.new(token: SecureRandom.base58(24), state: "active", rules_version: Game::DuelRules::VERSION, first_caller:,
      started_at: Time.current,
      challenger_cards: challenger.map(&:to_snapshot), opponent_cards: opponent.map(&:to_snapshot),
      challenger_draw_order: challenger.map(&:card_season_id).reverse, opponent_draw_order: opponent.map(&:card_season_id).reverse)
  end

  # Locks the next round's call: the caller's card, a stat and a direction; the round.
  def lock_call(duel, card_season_id, stat, direction, automatic: false)
    rules = Game::DuelRules.new(duel, duel.rounds.to_a)
    card = rules.card(rules.caller, card_season_id)
    duel.rounds.build(number: rules.round, caller: rules.caller.to_s, caller_card_season_id: card_season_id, stat: stat.to_s,
      direction: direction.to_s, caller_value: card.to_snapshot.dig("stats", stat.to_s, "value"), caller_automatic: automatic,
      called_at: Time.current)
  end

  # Answers the locked call with the answerer's card, the winner written as the rules decide it; the round.
  def answer_call(duel, card_season_id, automatic: false)
    rules = Game::DuelRules.new(duel, duel.rounds.to_a)
    round = rules.pending
    answer_card = rules.card(rules.answerer, card_season_id)
    outcome = Game::DuelRules.outcome(rules.card(rules.caller, round.caller_card_season_id), answer_card, round.stat.to_sym,
      round.direction.to_sym)
    winner = { caller: rules.caller, answerer: rules.answerer }[outcome.winner]
    round.assign_attributes(answer_card_season_id: card_season_id, answer_value: answer_card.to_snapshot.dig("stats", round.stat, "value"),
      answer_automatic: automatic, answered_at: Time.current, winner: winner&.to_s, decided_on_value: outcome.decided_on_value)
    round
  end

  # Plays the next round as the game does when both players run out of time.
  def play_automatic_round(duel)
    call = Game::DuelRules.new(duel, duel.rounds.to_a).automatic_call
    lock_call(duel, call.card.card_season_id, call.stat, call.direction, automatic: true)
    answer_call(duel, Game::DuelRules.new(duel, duel.rounds.to_a).automatic_answer.card_season_id, automatic: true)
  end

  def ids(cards) = cards.map(&:card_season_id)
end

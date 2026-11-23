require "test_helper"
require_relative "../../support/duels"

# The rules of a duel, read from its row and its rounds alone: who calls, what each hand holds and which stats each
# player has left, who takes a round and the duel, and the moves the game plays for a player out of time.
class Game::DuelRulesTest < ActiveSupport::TestCase
  include Duels

  def rules(duel) = Game::DuelRules.new(duel, duel.rounds.to_a)

  # The automatic opening call of a challenger whose deck is at 50 but the cards given; card, stat and direction.
  def automatic_call(given = {})
    call = rules(active_duel(challenger: deck_with(1001, given))).automatic_call
    [ call.card.card_season_id, call.stat, call.direction ]
  end

  def outcome(caller_card, answer_card, stat, direction)
    result = Game::DuelRules.outcome(caller_card, answer_card, stat, direction)
    [ result.winner, result.decided_on_value, result.margin ]
  end

  # Twelve cards from `first_id` at 50 but those given by place, 0 to 11; each deck is drawn from its last card.
  def deck_with(first_id, given = {})
    Array.new(12) { |index| duel_card(first_id + index, number: index + 1, **given.fetch(index, {})) }
  end

  # A duel whose round n opposes the challenger's card n, at challenger[n - 1] on rating, to the opponent's card n, at
  # opponent[n - 1], each called high; `rounds` of them played.
  def rated_duel(challenger, opponent, rounds: 10)
    rated = ->(ratings) { ratings.each_with_index.to_h { |rating, index| [ index, { rating: } ] } }
    duel = active_duel(challenger: deck_with(1001, rated.(challenger)), opponent: deck_with(2001, rated.(opponent)))
    rounds.times do |index|
      mine, theirs = 1001 + index, 2001 + index
      calling, answering = Game::DuelRules.caller(index + 1, "challenger") == :challenger ? [ mine, theirs ] : [ theirs, mine ]
      lock_call(duel, calling, :rating, :high)
      answer_call(duel, answering)
    end
    duel
  end

  test "the first caller calls rounds 1, 3, 5, 7 and 10, the other rounds 2, 4, 6, 8 and 9: five calls each" do
    assert_equal %i[challenger opponent challenger opponent challenger opponent challenger opponent opponent challenger],
      (1..10).map { Game::DuelRules.caller(it, "challenger") }
    assert_equal %i[opponent challenger opponent challenger opponent challenger opponent challenger challenger opponent],
      (1..10).map { Game::DuelRules.caller(it, :opponent) }
    assert_equal({ challenger: 5, opponent: 5 }, (1..10).map { Game::DuelRules.caller(it, "opponent") }.tally.sort.to_h)
    assert_equal [ :opponent, :challenger ], [ Game::DuelRules.other(:challenger), Game::DuelRules.other(:opponent) ]

    duel = active_duel(first_caller: "opponent")
    assert_equal [ 1, :opponent, :challenger ], [ rules(duel).round, rules(duel).caller, rules(duel).answerer ]
  end

  test "a player's stats left lose the stats of their revealed calls, never the stat of a call still locked" do
    duel = active_duel
    lock_call(duel, 1012, :rating, :high)
    answer_call(duel, 2012)
    lock_call(duel, 2011, :release, :low)
    answer_call(duel, 1011)
    lock_call(duel, 1010, :discovery, :high)

    assert_equal %i[popularity release discovery circulation], rules(duel).stats_left(:challenger)
    assert_equal %i[popularity rating discovery circulation], rules(duel).stats_left(:opponent)
  end

  test "a hand is the cards drawn so far less those played, in deck order: three, two once its owner locks a call" do
    duel = active_duel

    assert_equal [ 1010, 1011, 1012 ], ids(rules(duel).hand(:challenger))
    assert_equal [ 2010, 2011, 2012 ], ids(rules(duel).hand(:opponent))

    lock_call(duel, 1011, :rating, :high)
    assert_equal [ 1010, 1012 ], ids(rules(duel).hand(:challenger))
    assert_equal [ 2010, 2011, 2012 ], ids(rules(duel).hand(:opponent))
    assert_equal({ challenger: [ 1011 ], opponent: [] }, Game::DuelRules::ROLES.index_with { rules(duel).played(it) })

    answer_call(duel, 2012)
    assert_equal [ 2, :opponent ], [ rules(duel).round, rules(duel).caller ]
    assert_equal [ 1009, 1010, 1012 ], ids(rules(duel).hand(:challenger))
    assert_equal [ 2009, 2010, 2011 ], ids(rules(duel).hand(:opponent))
  end

  test "the tenth round is played with open hands: each deck less its nine played cards" do
    duel = active_duel
    9.times { play_automatic_round(duel) }
    played = rules(duel)

    assert_equal [ 10, :challenger, false ], [ played.round, played.caller, played.finished? ]
    Game::DuelRules::ROLES.each do |role|
      assert_equal 9, played.played(role).size
      assert_equal ids(played.deck(role)) - played.played(role), ids(played.hand(role))
    end
  end

  test "a round goes to the better percentile in the called direction, by the margin between the two" do
    assert_equal [ :caller, false, 20 ], outcome(duel_card(1, rating: 80), duel_card(2, rating: 60), :rating, :high)
    assert_equal [ :caller, false, 30 ], outcome(duel_card(1, rating: 30), duel_card(2, rating: 60), :rating, :low)
    assert_equal [ :answerer, false, 20 ], outcome(duel_card(1, rating: 60), duel_card(2, rating: 80), :rating, :high)
    assert_equal [ BigDecimal("70.5"), -1 ],
      [ Game::DuelRules.strength(duel_card(1, release: 29.5), :release, :low), Game::DuelRules.strength(duel_card(1, release: nil), :release, :low) ]
  end

  test "equal percentiles go to the better exact value in the direction, discovered first counting high, by no margin" do
    more = duel_card(1, popularity: 70, values: { popularity: 5_000 })
    fewer = duel_card(2, popularity: 70, values: { popularity: 4_000 })
    newer = duel_card(1, release: 40, values: { release: Date.new(2020, 5, 1) })
    older = duel_card(2, release: 40, values: { release: Date.new(2020, 4, 30) })
    first = duel_card(1, discovery: 40, values: { discovery: Time.utc(2026, 1, 1, 12, 0, 1) })
    last = duel_card(2, discovery: 40, values: { discovery: Time.utc(2026, 1, 1, 12, 0, 2) })

    assert_equal [ :caller, true, 0 ], outcome(more, fewer, :popularity, :high)
    assert_equal [ :answerer, true, 0 ], outcome(more, fewer, :popularity, :low)
    assert_equal [ :caller, true, 0 ], outcome(newer, older, :release, :high)
    assert_equal [ :answerer, true, 0 ], outcome(newer, older, :release, :low)
    assert_equal [ :caller, true, 0 ], outcome(first, last, :discovery, :high)
    assert_equal [ :answerer, true, 0 ], outcome(first, last, :discovery, :low)
  end

  test "equal ratings go to the edition with more reviews, whatever the direction" do
    popular = duel_card(1, rating: 70, values: { rating: 90, popularity: 5_000 })
    obscure = duel_card(2, rating: 70, values: { rating: 90, popularity: 4_000 })

    assert_equal [ :caller, true, 0 ], outcome(popular, obscure, :rating, :high)
    assert_equal [ :answerer, true, 0 ], outcome(popular, obscure, :rating, :low)
  end

  test "equal ratings still resolve when one edition has no review count" do
    reviewed = duel_card(1, rating: 70, values: { rating: 90, popularity: 12 })
    unreviewed = duel_card(2, rating: 70, values: { rating: 90, popularity: nil })

    assert_equal [ :caller, true, 0 ], outcome(reviewed, unreviewed, :rating, :high)
    assert_equal [ :answerer, true, 0 ], outcome(reviewed, unreviewed, :rating, :low)
  end

  test "equal ratings score nothing beside an edition with no rating value, and two without one go to the review count" do
    rated = duel_card(1, rating: 70, values: { rating: 90, popularity: 12 })
    unrated = duel_card(2, rating: 70, values: { rating: nil, popularity: 12 })
    reviewed_unrated = duel_card(3, rating: 70, values: { rating: nil, popularity: 40 })

    assert_equal [ nil, false, 0 ], outcome(rated, unrated, :rating, :high)
    assert_equal [ nil, false, 0 ], outcome(unrated, rated, :rating, :low)
    assert_equal [ :caller, true, 0 ], outcome(reviewed_unrated, unrated, :rating, :high)
  end

  test "equal percentiles and equal values score nothing" do
    assert_equal [ nil, false, 0 ], outcome(duel_card(1, rating: 70), duel_card(2, rating: 70), :rating, :high)
    assert_equal [ nil, false, 0 ], outcome(duel_card(1, rating: 70), duel_card(2, rating: 70), :rating, :low)

    duel = rated_duel([ 60 ], [ 60 ], rounds: 1)
    assert_equal [ nil ], rules(duel).played_rounds.map(&:winner)
    assert_equal({ challenger: 0, opponent: 0 }, rules(duel).scores)
  end

  test "a card without a value on the called stat loses in either direction, and two without one score nothing" do
    blank = duel_card(1, circulation: nil)
    rarest = duel_card(2, circulation: 0)

    assert_equal [ :answerer, false, 0 ], outcome(blank, rarest, :circulation, :high)
    assert_equal [ :answerer, false, 100 ], outcome(blank, rarest, :circulation, :low)
    assert_equal [ :caller, false, 100 ], outcome(rarest, blank, :circulation, :low)
    assert_equal [ nil, false, 0 ], outcome(blank, duel_card(2, circulation: nil), :circulation, :high)
  end

  test "the duel goes to the higher score, then the larger margin over the rounds won, else it is a draw" do
    by_score = rules(rated_duel([ 80 ] * 6 + [ 20 ] * 4, [ 60 ] * 10))
    assert_equal({ challenger: 6, opponent: 4 }, by_score.scores)
    assert_equal({ challenger: 120, opponent: 160 }, by_score.margins)
    assert_equal :challenger, by_score.result

    by_margin = rules(rated_duel([ 70 ] * 5 + [ 10 ] * 5, [ 60 ] * 10))
    assert_equal [ { challenger: 5, opponent: 5 }, { challenger: 50, opponent: 250 } ], [ by_margin.scores, by_margin.margins ]
    assert_equal :opponent, by_margin.result

    assert_equal :draw, rules(rated_duel([ 70 ] * 5 + [ 50 ] * 5, [ 60 ] * 10)).result
    assert_equal :draw, rules(rated_duel([ 60 ] * 10, [ 60 ] * 10)).result
  end

  test "a duel has no result until its tenth round is revealed" do
    duel = rated_duel([ 80 ] * 10, [ 60 ] * 10, rounds: 9)
    assert_nil rules(duel).result

    lock_call(duel, 1010, :rating, :high)
    assert_nil rules(duel).result
    assert_not rules(duel).finished?

    answer_call(duel, 2010)
    assert rules(duel).finished?
    assert_equal [ 10, :challenger, 10 ], [ rules(duel).round, rules(duel).result, rules(duel).played_rounds.size ]
  end

  test "an automatic call takes the strongest card and stat, then the larger median distance, the stat order, the earlier card" do
    strongest = automatic_call(9 => { rating: 85 }, 10 => { popularity: 90 }, 11 => { release: 9 })
    assert_equal [ 1012, :release, :low ], strongest

    farther = automatic_call(9 => { popularity: 90 }, 10 => { rating: 90, distances: { rating: 45.0 } })
    assert_equal [ 1011, :rating, :high ], farther

    stat_order = automatic_call(9 => { circulation: 90 }, 10 => { rating: 90 })
    assert_equal [ 1011, :rating, :high ], stat_order

    earlier = automatic_call(10 => { release: 10 }, 11 => { release: 10 })
    assert_equal [ 1011, :release, :low ], earlier

    assert_equal [ 1010, :popularity, :high ], automatic_call
  end

  test "an automatic call never takes a stat its caller has called" do
    duel = active_duel(challenger: deck_with(1001, 9 => { popularity: 99, rating: 80 }))
    lock_call(duel, 1012, :popularity, :high)
    answer_call(duel, 2012)
    lock_call(duel, 2011, :rating, :high)
    answer_call(duel, 1011)

    call = rules(duel).automatic_call
    assert_equal [ 3, [ 1008, 1009, 1010 ] ], [ rules(duel).round, ids(rules(duel).hand(:challenger)) ]
    assert_equal [ 1010, :rating, :high ], [ call.card.card_season_id, call.stat, call.direction ]
  end

  test "an automatic answer guesses the shown card's most extreme stat and side, then plays the hand card strongest there" do
    duel = active_duel(challenger: deck_with(1001, 9 => { popularity: 60, release: 10 }),
      opponent: deck_with(2001, 9 => { release: 40 }, 10 => { release: 5, popularity: 0 }, 11 => { popularity: 99, release: 70 }))
    lock_call(duel, 1010, :popularity, :high)

    assert_equal 2011, rules(duel).automatic_answer.card_season_id
  end

  test "an automatic answer leaves out the stats its caller has called, then breaks a tie by median distance and deck order" do
    duel = active_duel(challenger: deck_with(1001, 9 => { rating: 80, release: 1 }),
      opponent: deck_with(2001, 7 => { rating: 85 }, 8 => { rating: 85, distances: { rating: 40.0 } }, 9 => { rating: 85, distances: { rating: 40.0 } }))
    lock_call(duel, 1012, :release, :low)
    answer_call(duel, 2012)
    lock_call(duel, 2011, :popularity, :high)
    answer_call(duel, 1011)
    lock_call(duel, 1010, :circulation, :high)

    assert_equal [ 2008, 2009, 2010 ], ids(rules(duel).hand(:opponent))
    assert_equal 2009, rules(duel).automatic_answer.card_season_id
  end

  test "the rules read nothing from the database" do
    duel = active_duel

    assert_no_queries do
      play_automatic_round(duel)
      played = rules(duel)
      [ played.scores, played.margins, played.played_rounds, played.hand(:opponent), played.automatic_call ]
    end
  end
end

require "test_helper"
require_relative "../../support/duels"

# What a seat sees of a duel: plain data only, both decks with their played cards, its own hand and never the other's,
# the other's call hidden until its answer, no draw order, and no card at all before the duel starts.
class Game::DuelViewTest < ActiveSupport::TestCase
  include Duels

  def plain_classes
    [ Symbol, Integer, BigDecimal, Float, String, Date, Time, ActiveSupport::TimeWithZone, TrueClass, FalseClass, NilClass ]
  end

  def seats(duel) = Game::DuelRules::ROLES.map { duel.seats.build(role: it.to_s, status: "seated") }

  # Yields every value the view holds below Data, arrays and hashes, with its path.
  def leaves(value, path = [], &block)
    case value
    when Data then value.to_h.each { |key, item| leaves(item, path + [ key ], &block) }
    when Array then value.each_with_index { |item, index| leaves(item, path + [ index ], &block) }
    when Hash then value.each { |key, item| leaves(item, path + [ key ], &block) }
    else yield path, value
    end
  end

  def arrays(value, &block)
    case value
    when Data, Hash then value.to_h.each_value { arrays(it, &block) }
    when Array
      yield value
      value.each { arrays(it, &block) }
    end
  end

  def assert_plain(seen)
    leaves(seen) { |path, leaf| assert plain_classes.any? { it === leaf }, "#{path.join(".")} holds a #{leaf.class}" }
  end

  def assert_seat_view(duel, seat)
    rules = Game::DuelRules.new(duel, duel.rounds.to_a)
    role = seat.role.to_sym
    other = Game::DuelRules.other(role)
    seen = nil
    assert_no_queries { seen = Game::DuelView.for(duel, seat) }

    assert_plain(seen)
    assert_equal [ role, other ], [ seen.mine.role, seen.theirs.role ]
    assert_equal [ rules.deck(role), rules.deck(other) ], [ seen.mine.deck, seen.theirs.deck ]
    assert_equal [ rules.played(role), rules.played(other) ], [ seen.mine.played, seen.theirs.played ]
    assert_equal [ rules.round, rules.caller, rules.result ], [ seen.round, seen.caller, seen.result ]
    assert_equal rules.played_rounds, seen.rounds
    assert_equal [ duel.token, duel.state.to_sym ], [ seen.token, seen.state ]
    assert_hand(rules, seen, role)
    assert_call_hidden(rules, seen, role)
    assert_other_hand_hidden(duel, rules, seen, other)

    revealed = rules.revealed
    { mine: role, theirs: other }.each do |side, owner|
      called = revealed.select { it.caller == owner.to_s }.map { it.stat.to_sym }
      assert_equal Game::DuelStat::STATS - called, seen.public_send(side).stats_left
      assert_equal rules.scores.fetch(owner), seen.public_send(side).score
      assert_equal rules.margins.fetch(owner), seen.public_send(side).margin
    end
  end

  def assert_hand(rules, seen, role)
    locked = rules.pending&.caller == role.to_s
    assert_equal((rules.finished? || locked) ? 2 : 3, seen.hand.size)
    assert_equal ids(rules.hand(role)), ids(seen.hand)
    assert_equal ids(seen.hand), ids(rules.deck(role)) & ids(seen.hand)
  end

  def assert_call_hidden(rules, seen, role)
    locked = rules.pending
    return assert_nil(seen.current_call) if locked.nil?

    assert_equal locked.caller_card_season_id, seen.current_call.card.card_season_id
    shown = locked.caller == role.to_s ? [ locked.stat.to_sym, locked.direction.to_sym ] : [ nil, nil ]
    assert_equal shown, [ seen.current_call.stat, seen.current_call.direction ]
  end

  def assert_other_hand_hidden(duel, rules, seen, other)
    hidden = ids(rules.hand(other))
    beyond_decks = seen.with(mine: seen.mine.with(deck: []), theirs: seen.theirs.with(deck: []))
    leaves(beyond_decks) { |path, leaf| assert_not_includes hidden, leaf, "#{path.join(".")} shows a card in the other hand" }
    draws = Game::DuelRules::ROLES.map { duel.draw_order(it) }
    arrays(seen) { |list| assert_not_includes draws, list }
  end

  test "each seat sees both decks, its own hand and its own call only, at every call and answer of a whole duel" do
    duel = active_duel
    duel_seats = seats(duel)
    duel_seats.each { assert_seat_view(duel, it) }

    10.times do
      call = Game::DuelRules.new(duel, duel.rounds.to_a).automatic_call
      lock_call(duel, call.card.card_season_id, call.stat, call.direction)
      duel_seats.each { assert_seat_view(duel, it) }

      answer_call(duel, Game::DuelRules.new(duel, duel.rounds.to_a).automatic_answer.card_season_id)
      duel_seats.each { assert_seat_view(duel, it) }
    end

    rules = Game::DuelRules.new(duel, duel.rounds.to_a)
    duel.assign_attributes(state: "finished", ended_at: Time.current, result: rules.result.to_s)
    duel_seats.each do |seat|
      assert_seat_view(duel, seat)
      seen = Game::DuelView.for(duel, seat)
      assert_equal :finished, seen.state
      assert_includes %i[challenger opponent draw], seen.result
      assert_equal [ 10, [], [] ], [ seen.rounds.size, seen.mine.stats_left, seen.theirs.stats_left ]
    end
  end

  test "the opponent calling first sees its call while the challenger sees only the card shown" do
    duel = active_duel(first_caller: "opponent")
    challenger, opponent = seats(duel)
    lock_call(duel, 2012, :rating, :low)

    assert_equal [ :rating, :low ], Game::DuelView.for(duel, opponent).current_call.to_h.values_at(:stat, :direction)
    assert_equal [ 2012, nil, nil ], Game::DuelView.for(duel, challenger).current_call.then { [ it.card.card_season_id, it.stat, it.direction ] }
    [ challenger, opponent ].each { assert_seat_view(duel, it) }
  end

  test "a duel not started shows no card to either seat, even with its decks drawn and a call locked" do
    %w[challenged cancelled refused lapsed].each do |state|
      duel = active_duel
      lock_call(duel, 1012, :rating, :high)
      duel.state = state

      seats(duel).each do |seat|
        seen = Game::DuelView.for(duel, seat)

        assert_plain(seen)
        assert_equal [ state.to_sym, nil, nil, nil, nil, [], [] ],
          [ seen.state, seen.round, seen.caller, seen.current_call, seen.result, seen.hand, seen.rounds ]
        [ seen.mine, seen.theirs ].each do |side|
          assert_equal [ [], [], 0, 0, Game::DuelStat::STATS ], [ side.deck, side.played, side.score, side.margin, side.stats_left ]
        end
        leaves(seen) { |path, leaf| assert_not_includes 1001..2012, leaf, "#{path.join(".")} names a card" if leaf.is_a?(Integer) }
      end
    end
  end

  test "a seat at a saved duel reads the rounds back and writes nothing" do
    portal = catalog_card_seasons(:portal_one).id
    common = catalog_card_seasons(:common_card_one).id
    duel = active_duel(challenger: duel_deck(1001).first(11) + [ duel_card(portal, number: 12, rating: 80) ],
      opponent: duel_deck(2001).first(11) + [ duel_card(common, number: 12, rating: 60) ])
    duel.save!
    seat = duel.seats.create!(role: "challenger", status: "seated", player_id: accounts_players(:player).id)
    lock_call(duel, portal, :rating, :high)
    answer_call(duel, common)
    duel.save!

    seen = nil
    assert_no_queries_match(/INSERT|UPDATE|DELETE/i) { seen = Game::DuelView.for(Game::Duel.find(duel.id), seat) }
    assert_equal [ [ 1, :challenger, :challenger, 20 ] ], seen.rounds.map { [ it.number, it.caller, it.winner, it.margin ] }
    assert_equal [ 1, 20, [ portal ], [ common ] ], [ seen.mine.score, seen.mine.margin, seen.mine.played, seen.theirs.played ]
  end

  test "a seat of another duel cannot see this one" do
    duel = Game::Duel.create!
    seat = Game::DuelSeat.create!(duel: Game::Duel.create!, role: "challenger", status: "seated", player_id: accounts_players(:player).id)

    assert_raises(ArgumentError) { Game::DuelView.for(duel, seat) }
  end
end

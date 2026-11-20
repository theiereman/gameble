require "test_helper"
require_relative "../../support/game_packs"
require_relative "../../support/live_duels"

# Challenging a friend and accepting the challenge: the seats, the frozen decks, the draws and one event each; a
# refusal writes nothing, except an acceptance finding a deck no longer ready, which lapses the challenge.
class Game::DuelChallengeOperationsTest < ActiveSupport::TestCase
  include GamePacks
  include LiveDuels

  setup do
    @lea = accounts_players(:player)
    @hugo = accounts_players(:moderator)
    @max = accounts_players(:administrator)
    befriend(@lea, @hugo)
    @lea_deck = complete_deck(@lea, "Lea")
    @hugo_deck = complete_deck(@hugo, "Hugo")
  end

  def challenge(player: @lea, friend: @hugo, deck_token: @lea_deck.token)
    Game::ChallengeFriend.new.call(player:, friend:, deck_token:)
  end

  def accept(duel, player: @hugo, deck_token: @hugo_deck.token, move_number: duel.move_number)
    Game::AcceptChallenge.new.call(player:, token: duel.token, deck_token:, move_number:)
  end

  def seats_of(duel) = Game::DuelSeat.where(duel_id: duel.id).order(:id).index_by(&:role)

  def seat(player, status, role: "challenger")
    Game::DuelSeat.create!(duel: Game::Duel.create!, role:, player_id: player.id, status:)
  end

  def written(duel = nil)
    duel_rows = duel && [ Game::Duel.find(duel.id).attributes, Game::DuelSeat.where(duel_id: duel.id).order(:id).map(&:attributes) ]
    [ Game::Duel.count, Game::DuelSeat.count, Game::DuelRound.count, Rails.configuration.event_store.read.count, duel_rows ]
  end

  def assert_refused(code, duel = nil, &operation)
    before = written(duel)
    assert_equal code, operation.call.failure
    assert_equal before, written(duel)
  end

  def duel_data(duel) = { duel_id: duel.id, challenger_id: @lea.id, opponent_id: @hugo.id }

  test "a challenge seats the challenger with their deck, invites the friend and writes one event" do
    duel = challenge.value!

    assert_equal [ "challenged", 0 ], [ duel.state, duel.move_number ]
    assert_match(/\A[1-9A-HJ-NP-Za-km-z]{24}\z/, duel.token)
    seats = seats_of(duel)
    assert_equal [ @lea.id, "seated", @lea_deck.token ], [ seats["challenger"].player_id, seats["challenger"].status, seats["challenger"].deck_token ]
    assert_equal [ @hugo.id, "invited", nil ], [ seats["opponent"].player_id, seats["opponent"].status, seats["opponent"].deck_token ]
    assert_equal [ duel_data(duel) ], game_events(@lea, Game::DuelChallengeSent).map(&:data)
  end

  test "a challenge needs a friend open to friends" do
    befriend(@lea, @max)

    assert_refused(:not_a_friend) { challenge(friend: nil) }
    assert_refused(:not_a_friend) { challenge(friend: @lea) }
    assert_refused(:not_a_friend) { challenge(friend: accounts_players(:banned)) }
    @max.update_columns(banned_at: Time.current)
    assert_refused(:not_a_friend) { challenge(friend: @max) }
    @hugo.update_columns(visibility: "private")
    assert_refused(:friend_duels_closed) { challenge }
    @lea.update_columns(visibility: "private")
    assert_refused(:own_duels_closed) { challenge }
  end

  test "a challenge is refused to a friend whose lease lapsed or never began" do
    @hugo.update_columns(reachable_until: 1.second.ago)
    assert_refused(:friend_unavailable) { challenge }

    @hugo.update_columns(reachable_until: nil)
    assert_refused(:friend_unavailable) { challenge }
  end

  test "a challenge is refused to a player already seated, and to a friend seated or invited" do
    seated = seat(@lea, "seated")
    assert_refused(:duel_in_progress) { challenge }

    seated.update!(status: "left")
    invited = seat(@lea, "invited", role: "opponent")
    assert_refused(:duel_in_progress) { challenge }

    invited.update!(status: "left")
    seat(@hugo, "invited", role: "opponent")
    assert_refused(:friend_busy) { challenge }

    Game::DuelSeat.where(player_id: @hugo.id).update_all(status: "seated")
    assert_refused(:friend_busy) { challenge }
  end

  test "a challenge needs the challenger's own deck, complete, each card still held" do
    assert_refused(:deck_not_ready) { challenge(deck_token: "Zz" * 12) }
    assert_refused(:deck_not_ready) { challenge(deck_token: @hugo_deck.token) }
    assert_refused(:deck_not_ready) { challenge(deck_token: 42) }

    held = Game::DeckCard.where(deck_id: @lea_deck.id).order(:slot).first
    Game::Holding.where(player_id: @lea.id, card_season_id: held.card_season_id).update_all(quantity: 0, reserved: 0)
    assert_refused(:deck_not_ready) { challenge }

    Game::Holding.where(player_id: @lea.id).update_all(quantity: 1)
    held.destroy!
    assert_refused(:deck_not_ready) { challenge }
  end

  test "an acceptance freezes both decks, draws both orders and the first caller, seats the friend and writes one event" do
    challenged = challenge.value!
    challenged.update_columns(rules_version: Game::DuelRules::VERSION - 1)
    duel = accept(challenged).value!.reload

    assert_equal [ "active", 1, Game::DuelRules::VERSION ], [ duel.state, duel.move_number, duel.rules_version ]
    assert duel.started_at
    assert_includes %w[challenger opponent], duel.first_caller
    assert_equal Game::DuelSnapshot.call(@lea_deck).map(&:to_snapshot), duel.challenger_cards
    assert_equal Game::DuelSnapshot.call(@hugo_deck).map(&:to_snapshot), duel.opponent_cards
    { challenger: @lea_deck, opponent: @hugo_deck }.each do |role, deck|
      assert_equal Game::DeckCard.where(deck_id: deck.id).pluck(:card_season_id).sort, duel.draw_order(role).sort
    end
    seats = seats_of(duel)
    assert_equal %w[seated seated], seats.values.map(&:status)
    assert_equal @hugo_deck.token, seats["opponent"].deck_token
    assert_equal [ duel_data(duel) ], game_events(@hugo, Game::DuelChallengeAccepted).map(&:data)
  end

  test "the frozen decks hold whatever becomes of the decks afterwards" do
    duel = accept(challenge.value!).value!
    views = seats_of(duel).values.map { Game::DuelView.for(Game::Duel.find(duel.id), it).with(server_time: nil) }
    cards = Game::Duel.find(duel.id).challenger_cards

    Game::DeckCard.where(deck_id: @lea_deck.id).order(:slot).first.destroy!
    Game::DeleteDeck.new.call(player: @hugo, token: @hugo_deck.token).value!

    assert_equal cards, Game::Duel.find(duel.id).challenger_cards
    assert_equal views, seats_of(duel).values.map { Game::DuelView.for(Game::Duel.find(duel.id), it).with(server_time: nil) }
  end

  test "an acceptance finding a deck no longer ready lapses the challenge and is refused" do
    duel = challenge.value!
    Game::DeckCard.where(deck_id: @lea_deck.id).order(:slot).first.destroy!

    assert_equal :deck_not_ready, accept(duel).failure

    duel.reload
    assert_equal [ "lapsed", 1 ], [ duel.state, duel.move_number ]
    assert duel.ended_at
    assert_equal %w[left left], seats_of(duel).values.map(&:status)
    assert_equal [ duel_data(duel) ], game_events(@hugo, Game::DuelChallengeLapsed).map(&:data)
    assert_empty game_events(@hugo, Game::DuelChallengeAccepted)
  end

  test "an acceptance with a deck of the acceptor not ready lapses the challenge too" do
    duel = challenge.value!
    Game::DeckCard.where(deck_id: @hugo_deck.id).order(:slot).first.destroy!

    assert_equal :deck_not_ready, accept(duel).failure

    assert_equal "lapsed", duel.reload.state
  end

  test "an acceptance with an unknown, stale or foreign deck token is refused and leaves the challenge standing" do
    duel = challenge.value!

    [ "Zz" * 12, @lea_deck.token, nil, 42 ].each do |token|
      assert_refused(:deck_not_found, duel) { accept(duel, deck_token: token) }
    end

    assert_equal [ "challenged", 0 ], [ duel.reload.state, duel.move_number ]
    assert_empty game_events(@hugo, Game::DuelChallengeLapsed)
  end

  test "an acceptance is refused out of turn, stale or no longer due, and writes nothing" do
    duel = challenge.value!

    assert_refused(:not_your_move, duel) { accept(duel, player: @lea, deck_token: @lea_deck.token) }
    assert_refused(:not_your_move, duel) { accept(duel, move_number: 1) }
    assert_refused(:invalid_move, duel) { accept(duel, move_number: "one") }
    assert_refused(:duel_not_found, duel) { accept(duel, player: @max) }
    assert_refused(:duel_not_found, duel) { Game::AcceptChallenge.new.call(player: @hugo, token: nil, deck_token: @hugo_deck.token, move_number: 0) }

    accept(duel).value!
    assert_refused(:not_your_move, duel) { accept(duel, move_number: 0) }
    assert_refused(:not_your_move, duel) { accept(duel, move_number: 1) }
  end

  test "an acceptance is refused to a player seated elsewhere or no longer a friend open to friends" do
    duel = challenge.value!

    elsewhere = seat(@hugo, "seated")
    assert_refused(:duel_in_progress, duel) { accept(duel) }
    elsewhere.update!(status: "left")

    @lea.update_columns(visibility: "private")
    assert_refused(:friend_duels_closed, duel) { accept(duel) }
    @lea.update_columns(visibility: "public")
    @hugo.update_columns(visibility: "private")
    assert_refused(:own_duels_closed, duel) { accept(duel) }
    @hugo.update_columns(visibility: "public")

    Game::Friendship.delete_all
    assert_refused(:not_a_friend, duel) { accept(duel) }
  end

  def cancel(duel, player: @lea) = Game::CancelChallenge.new.call(player:, token: duel.token)

  def refuse(duel, player: @hugo) = Game::RefuseChallenge.new.call(player:, token: duel.token)

  def assert_ended(duel, state, event, by: @lea)
    duel.reload
    assert_equal [ state, 1 ], [ duel.state, duel.move_number ]
    assert duel.ended_at
    assert_equal %w[left left], seats_of(duel).values.map(&:status)
    assert_equal [ duel_data(duel) ], game_events(by, event).map(&:data)
    assert_equal 1, Rails.configuration.event_store.read.of_type([ event ]).count
    assert_empty Game::HeldSeats.call(@lea).to_h.values.compact
  end

  test "the challenger cancels a challenge nobody answered: both seats leave and one event is written" do
    duel = challenge.value!

    cancel(duel).value!

    assert_ended(duel, "cancelled", Game::DuelChallengeCancelled)
  end

  test "the invited friend refuses a challenge: both seats leave and one event is written" do
    duel = challenge.value!

    refuse(duel).value!

    assert_ended(duel, "refused", Game::DuelChallengeRefused, by: @hugo)
  end

  test "a cancellation or a refusal by the other side or an outsider writes nothing" do
    duel = challenge.value!

    assert_refused(:not_your_move, duel) { cancel(duel, player: @hugo) }
    assert_refused(:not_your_move, duel) { refuse(duel, player: @lea) }
    assert_refused(:duel_not_found, duel) { cancel(duel, player: @max) }
    assert_refused(:duel_not_found, duel) { refuse(duel, player: @max) }
    assert_refused(:duel_not_found, duel) { Game::CancelChallenge.new.call(player: @lea, token: nil) }
  end

  test "a challenge accepted cannot be cancelled nor refused" do
    accepted = accept(challenge.value!).value!

    assert_refused(:not_your_move, accepted) { cancel(accepted) }
    assert_refused(:not_your_move, accepted) { refuse(accepted) }
  end

  test "a challenge lapsed or already ended cannot be cancelled nor refused again" do
    lapsed = challenge.value!
    travel 61.seconds
    Game::LapseChallenge.new.call(player: @lea, token: lapsed.token, move_number: 0).value!
    assert_refused(:not_your_move, lapsed) { cancel(lapsed) }
    assert_refused(:not_your_move, lapsed) { refuse(lapsed) }

    refused = challenge.value!
    refuse(refused).value!
    assert_refused(:not_your_move, refused) { cancel(refused) }
    assert_refused(:not_your_move, refused) { refuse(refused) }
  end

  test "after a cancellation or a refusal both players are free to challenge again" do
    cancel(challenge.value!).value!
    refuse(challenge.value!).value!

    assert_equal "challenged", challenge.value!.state
  end
end

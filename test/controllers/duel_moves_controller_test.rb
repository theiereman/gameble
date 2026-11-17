require "test_helper"
require_relative "../support/steam_sign_in"
require_relative "../support/live_duels"

# POST /:locale/duels/challenges and /:locale/duels/:token/{acceptance,calls,answers}: each move runs its operation and
# leads back to Duels or to the duel, a refusal shown as the alert; only a player holding a seat may move.
class DuelMovesControllerTest < ActionDispatch::IntegrationTest
  include SteamSignIn
  include LiveDuels

  setup do
    @lea = accounts_players(:player)
    @hugo = accounts_players(:moderator)
    befriend(@lea, @hugo)
    complete_deck(@lea, "Lea")
    complete_deck(@hugo, "Hugo")
  end

  def challenge = Game::ChallengeFriend.new.call(player: @lea, friend: @hugo, deck_token: deck_token_of(@lea)).value!

  test "a challenge leads back to Duels, and a second one comes back with the refusal" do
    sign_in(@lea)

    post duel_challenges_path(locale: :en), params: { friend: @hugo.token, deck: deck_token_of(@lea) }

    assert_redirected_to duels_path(locale: :en, friend: @hugo.token)
    assert_nil flash[:alert]
    assert_equal [ "challenged" ], Game::Duel.pluck(:state)

    post duel_challenges_path(locale: :en), params: { friend: @hugo.token, deck: deck_token_of(@lea) }

    assert_redirected_to duels_path(locale: :en)
    assert_equal "You already have a duel in progress.", flash[:alert]
    assert_equal 1, Game::Duel.count
  end

  test "a challenge to an unknown player is refused as not a friend" do
    sign_in(@lea)

    post duel_challenges_path(locale: :fr), params: { friend: "nobody", deck: deck_token_of(@lea) }

    assert_redirected_to duels_path(locale: :fr)
    assert_equal "Ce joueur ne fait pas partie de vos amis.", flash[:alert]
  end

  test "a challenge to a friend no longer reachable or already busy comes back with the friend named, not the alert" do
    sign_in(@lea)
    @hugo.update_columns(reachable_until: 1.minute.ago)

    post duel_challenges_path(locale: :en), params: { friend: @hugo.token, deck: deck_token_of(@lea) }

    assert_redirected_to duels_path(locale: :en, friend: @hugo.token)
    assert_equal @hugo.token, flash[:gone_friend]
    assert_nil flash[:alert]
    assert_equal 0, Game::Duel.count
  end

  test "a refusal ends the challenge and leads back with its notice; the challenger cannot refuse" do
    duel = challenge

    sign_in(@lea)
    post duel_refusal_path(locale: :en, token: duel.token)
    assert_redirected_to duels_path(locale: :en)
    assert_equal "This move is no longer yours to play.", flash[:alert]

    sign_in(@hugo)
    post duel_refusal_path(locale: :en, token: duel.token), headers: { "HTTP_REFERER" => friends_url(locale: :en) }

    assert_redirected_to friends_url(locale: :en)
    assert_equal "Challenge refused.", flash[:notice]
    assert_equal "refused", duel.reload.state
  end

  test "a cancellation ends the challenge and leads back to Duels; the invited friend cannot cancel" do
    duel = challenge

    sign_in(@hugo)
    post duel_cancellation_path(locale: :en, token: duel.token)
    assert_equal "This move is no longer yours to play.", flash[:alert]

    sign_in(@lea)
    post duel_cancellation_path(locale: :en, token: duel.token)

    assert_redirected_to duels_path(locale: :en)
    assert_equal "cancelled", duel.reload.state
  end

  test "an outsider cannot refuse nor cancel" do
    duel = challenge
    sign_in(accounts_players(:administrator))

    post duel_refusal_path(locale: :en, token: duel.token)
    assert_response :forbidden
    post duel_cancellation_path(locale: :en, token: duel.token)
    assert_response :forbidden
    assert_equal "challenged", duel.reload.state
  end

  test "an acceptance opens the duel; a stale one goes back to Duels with the refusal" do
    duel = challenge
    sign_in(@hugo)

    post duel_acceptance_path(locale: :en, token: duel.token), params: { deck: deck_token_of(@hugo), move_number: 1 }

    assert_redirected_to duels_path(locale: :en)
    assert_equal "This move is no longer yours to play.", flash[:alert]

    post duel_acceptance_path(locale: :en, token: duel.token), params: { deck: deck_token_of(@hugo), move_number: 0 }

    assert_redirected_to duel_path(locale: :en, token: duel.token)
    assert_equal "active", duel.reload.state
  end

  test "a call and an answer lead back to the duel, a refused move with the refusal" do
    duel = start_duel(@lea, @hugo)
    rules = rules_of(Game::Duel.find(duel.id))
    call = rules.automatic_call
    sign_in(seat_player(duel, rules.caller))

    post duel_calls_path(locale: :en, token: duel.token),
      params: { card: position_of(rules, rules.caller, call.card), stat: call.stat, direction: call.direction, move_number: 1 }

    assert_redirected_to duel_path(locale: :en, token: duel.token)
    assert_nil flash[:alert]
    assert_equal 2, duel.reload.move_number

    post duel_calls_path(locale: :en, token: duel.token), params: { card: 1, stat: "luck", direction: "high", move_number: 2 }
    assert_redirected_to duel_path(locale: :en, token: duel.token)
    assert_equal "That move could not be read. Reload the page.", flash[:alert]

    post duel_calls_path(locale: :en, token: duel.token), params: { card: 1, stat: { name: "rating" }, direction: "high", move_number: 2 }
    assert_equal "That move could not be read. Reload the page.", flash[:alert]

    locked = rules_of(Game::Duel.find(duel.id))
    sign_in(seat_player(duel, locked.answerer))
    post duel_answers_path(locale: :en, token: duel.token),
      params: { card: position_of(locked, locked.answerer, locked.automatic_answer), move_number: 2 }

    assert_redirected_to duel_path(locale: :en, token: duel.token)
    assert_nil flash[:alert]
    assert_equal 3, duel.reload.move_number
  end

  test "a move sent again after it landed is refused by its move number and never played twice; a resent one comes back without an alert" do
    duel = start_duel(@lea, @hugo)
    rules = rules_of(Game::Duel.find(duel.id))
    call = rules.automatic_call
    params = { card: position_of(rules, rules.caller, call.card), stat: call.stat, direction: call.direction, move_number: 1 }
    sign_in(seat_player(duel, rules.caller))

    post duel_calls_path(locale: :en, token: duel.token), params: params
    assert_equal 2, duel.reload.move_number

    post duel_calls_path(locale: :en, token: duel.token), params: params.merge(resent: 1)
    assert_redirected_to duel_path(locale: :en, token: duel.token)
    assert_nil flash[:alert]
    assert_equal [ 2, 1 ], [ duel.reload.move_number, duel.rounds.count ]

    post duel_calls_path(locale: :en, token: duel.token), params: params.merge(resent: 0)
    assert_equal "This move is no longer yours to play.", flash[:alert]
    assert_equal [ 2, 1 ], [ duel.reload.move_number, duel.rounds.count ]
  end

  test "an answer sent again after it landed comes back without an alert and is never played twice" do
    duel = call_round(start_duel(@lea, @hugo))
    rules = rules_of(Game::Duel.find(duel.id))
    params = { card: position_of(rules, rules.answerer, rules.automatic_answer), move_number: 2 }
    sign_in(seat_player(duel, rules.answerer))

    post duel_answers_path(locale: :en, token: duel.token), params: params
    assert_equal 3, duel.reload.move_number

    post duel_answers_path(locale: :en, token: duel.token), params: params.merge(resent: 1)
    assert_redirected_to duel_path(locale: :en, token: duel.token)
    assert_nil flash[:alert]
    assert_equal [ 3, 1 ], [ duel.reload.move_number, duel.rounds.count ]
  end

  test "a player holding no seat is refused every move, and a visitor is sent to sign in" do
    duel = challenge

    post duel_acceptance_path(locale: :en, token: duel.token), params: { deck: deck_token_of(@hugo), move_number: 0 }
    assert_redirected_to home_path(locale: :en)

    sign_in(accounts_players(:administrator))
    post duel_acceptance_path(locale: :en, token: duel.token), params: { deck: deck_token_of(@hugo), move_number: 0 }
    assert_response :forbidden
    post duel_calls_path(locale: :en, token: duel.token), params: { card: 1, stat: "rating", direction: "high", move_number: 0 }
    assert_response :forbidden
    post duel_answers_path(locale: :en, token: duel.token), params: { card: 1, move_number: 0 }
    assert_response :forbidden
    assert_equal "challenged", duel.reload.state
  end
end

class DuelMovesController < ApplicationController
  require_feature :duels
  throttle_player to: 60, only: %i[challenge practice accept decline cancel forfeit announce answer], path: -> { duels_path }, alert: "duels.throttled"

  def challenge
    authorize :duel, :challenge?, policy_class: DuelPolicy
    result = Game::ChallengeFriend.new.call(player: current_player, friend: Accounts::PlayerByToken.call(params[:friend]),
      deck_token: params[:deck])
    return friend_gone(params[:friend]) if %i[friend_unavailable friend_busy].include?(result.failure)

    settled(Game::ChallengeFriend, result, duels_path(friend: params[:friend]), failed_to: duels_path)
  end

  def practice
    authorize :duel, :practice?, policy_class: DuelPolicy
    result = Game::StartPracticeDuel.new.call(player: current_player, deck_token: params[:deck])
    return redirect_refused(Game::StartPracticeDuel, result, duels_path) if result.failure?

    redirect_to duel_path(token: result.value!.token), status: :see_other
  end

  def accept
    duel = authorized_duel(:accept?)
    result = Game::AcceptChallenge.new.call(player: current_player, token: duel.token, deck_token: params[:deck],
      move_number: params[:move_number])
    settled(Game::AcceptChallenge, result, duel_path(token: duel.token), failed_to: duels_path)
  end

  def decline
    duel = authorized_duel(:refuse?)
    result = Game::RefuseChallenge.new.call(player: current_player, token: duel.token)
    return redirect_refused(Game::RefuseChallenge, result, duels_path) if result.failure?

    redirect_back_or_to duels_path, notice: t("duels.received.refused"), status: :see_other
  end

  def cancel
    duel = authorized_duel(:cancel?)
    result = Game::CancelChallenge.new.call(player: current_player, token: duel.token)
    settled(Game::CancelChallenge, result, duels_path)
  end

  def forfeit
    duel = authorized_duel(:forfeit?)
    result = Game::ForfeitDuel.new.call(player: current_player, token: duel.token)
    settled(Game::ForfeitDuel, result, duel_path(token: duel.token), failed_to: duels_path)
  end

  def announce
    duel = authorized_duel(:announce?)
    moved(duel, Game::CallRound, Game::CallRound.new.call(player: current_player, token: duel.token, move_number: params[:move_number],
      card: params[:card], stat: params[:stat], direction: params[:direction]))
  end

  def answer
    duel = authorized_duel(:answer?)
    moved(duel, Game::AnswerRound, Game::AnswerRound.new.call(player: current_player, token: duel.token, move_number: params[:move_number],
      card: params[:card]))
  end

  private
    def friend_gone(token)
      flash[:gone_friend] = token
      redirect_to duels_path(friend: token), status: :see_other
    end

    def authorized_duel(query)
      authorize(Game::DuelByToken.call(params[:token]) || :duel, query, policy_class: DuelPolicy)
    end

    def moved(duel, operation, result)
      return redirect_to(duel_path(token: duel.token), status: :see_other) if repeated?(result)
      settled(operation, result, duel_path(token: duel.token))
    end

    def settled(operation, result, to, failed_to: to)
      return redirect_refused(operation, result, failed_to) if result.failure?

      redirect_to to, status: :see_other
    end

    def repeated?(result) = params[:resent] == "1" && result.failure == :not_your_move
end

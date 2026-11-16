class DuelMovesController < ApplicationController
  throttle_player to: 60, only: %i[challenge accept refuse cancel announce answer], path: -> { duels_path }, alert: "duels.throttled"

  def challenge
    authorize :duel, :challenge?, policy_class: DuelPolicy
    result = Game::ChallengeFriend.new.call(player: current_player, friend: Accounts::PlayerByToken.call(params[:friend]),
      deck_token: params[:deck])
    return friend_gone(params[:friend]) if %i[friend_unavailable friend_busy].include?(result.failure)
    return redirect_refused(Game::ChallengeFriend, result, duels_path) if result.failure?

    redirect_to duels_path(friend: params[:friend]), status: :see_other
  end

  def accept
    duel = authorized_duel(:accept?)
    result = Game::AcceptChallenge.new.call(player: current_player, token: duel.token, deck_token: params[:deck],
      move_number: params[:move_number])
    return redirect_refused(Game::AcceptChallenge, result, duels_path) if result.failure?

    redirect_to duel_path(token: duel.token), status: :see_other
  end

  def refuse
    duel = authorized_duel(:refuse?)
    result = Game::RefuseChallenge.new.call(player: current_player, token: duel.token)
    return redirect_refused(Game::RefuseChallenge, result, duels_path) if result.failure?

    redirect_back_or_to duels_path, notice: t("duels.received.refused"), status: :see_other
  end

  def cancel
    duel = authorized_duel(:cancel?)
    result = Game::CancelChallenge.new.call(player: current_player, token: duel.token)
    return redirect_refused(Game::CancelChallenge, result, duels_path) if result.failure?

    redirect_to duels_path, status: :see_other
  end

  def announce
    duel = authorized_duel(:announce?)
    stat, direction = params[:call].split("-", 2) if params[:call].is_a?(String)
    moved(duel, Game::CallRound, Game::CallRound.new.call(player: current_player, token: duel.token, move_number: params[:move_number],
      card: params[:card], stat:, direction:))
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
      return redirect_refused(operation, result, duel_path(token: duel.token)) if result.failure?

      redirect_to duel_path(token: duel.token), status: :see_other
    end
end

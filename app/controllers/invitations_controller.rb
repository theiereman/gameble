class InvitationsController < ApplicationController
  include InvitationFeedback

  throttle_player to: 20, only: %i[create accept ignore cancel], path: -> { friends_path }, alert: "invitations.throttled"

  def create
    authorize :invitation, :create?

    result = Game::SendInvitation.new.call(player: current_player, code: params[:code].to_s)
    report_sent(result)
  end

  def accept
    authorize :invitation, :accept?

    result = Game::AcceptInvitation.new.call(player: current_player, token: params[:token])
    if result.success?
      new_friend(result.value!.sender_id)
    else
      flash[:invite_error] = Game::AcceptInvitation.failure_message(result.failure)
    end
    redirect_to friends_path, status: :see_other
  end

  def ignore
    authorize :invitation, :ignore?

    result = Game::IgnoreInvitation.new.call(player: current_player, token: params[:token])
    flash[:invite_error] = Game::IgnoreInvitation.failure_message(result.failure) if result.failure?
    redirect_to friends_path, status: :see_other
  end

  def cancel
    authorize :invitation, :cancel?

    result = Game::CancelInvitation.new.call(player: current_player, token: params[:token])
    if result.success?
      flash[:invite_done] = t("invitations.cancelled")
    else
      flash[:invite_error] = Game::CancelInvitation.failure_message(result.failure)
    end
    redirect_to friends_path, status: :see_other
  end
end

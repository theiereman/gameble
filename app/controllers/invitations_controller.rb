# Friend invitations from the Friends screen (CAP-10, AD-8; EXPERIENCE.md,
# Amis): sending one by friend code, accepting or ignoring one received. Each
# answers with a redirect to the Friends screen; the line under the code
# field (or the "NOUVEL AMI" toast) carries the outcome. Game's operations do
# the work, and mutations are limited to 20 a minute per player.
class InvitationsController < ApplicationController
  include InvitationFeedback

  rate_limit to: 20, within: 1.minute, only: %i[create accept ignore],
    by: -> { current_player&.id || request.remote_ip },
    with: -> { redirect_to friends_path, alert: t("invitations.throttled"), status: :see_other }

  # POST /:locale/friends/invitations
  def create
    authorize :invitation, :create?

    code = params[:code].to_s.strip.upcase
    result = Game::SendInvitation.new.call(player: current_player, code: params[:code].to_s)
    report_sent(result, to: code)
  end

  # POST /:locale/friends/invitations/:token/accept
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

  # POST /:locale/friends/invitations/:token/ignore
  def ignore
    authorize :invitation, :ignore?

    result = Game::IgnoreInvitation.new.call(player: current_player, token: params[:token])
    flash[:invite_error] = Game::IgnoreInvitation.failure_message(result.failure) if result.failure?
    redirect_to friends_path, status: :see_other
  end
end

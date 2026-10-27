class BrotherInvitationsController < ApplicationController
  include InvitationFeedback

  rate_limit to: 20, within: 1.minute, only: :create,
    by: -> { current_player&.id || request.remote_ip },
    with: -> { redirect_to brother_path(token: params[:token]), alert: t("invitations.throttled"), status: :see_other }

  def create
    authorize :invitation, :create?

    owner = Accounts::PlayerByToken.call(params[:token])
    return render "public_profiles/unavailable", status: :not_found unless Game::Visibility.visible?(current_player, owner, staff_sees_all: false)

    result = Game::SendInvitation.new.call(player: current_player, recipient_token: owner.token)
    report_on_profile(result, owner)
    redirect_to brother_path(token: owner.token), status: :see_other
  end

  private
    def report_on_profile(result, owner)
      if result.failure?
        flash[:alert] = Game::SendInvitation.failure_message(result.failure)
      elsif result.value!.status == "accepted"
        new_friend(result.value!.sender_id)
      else
        flash[:notice] = t("invitations.sent", to: helpers.friend_name(owner))
      end
    end
end

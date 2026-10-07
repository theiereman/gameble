class InviteLinksController < ApplicationController
  include InvitationFeedback

  rate_limit to: 20, within: 1.minute, only: :create,
    by: -> { current_player&.id || request.remote_ip },
    with: -> { redirect_to friends_path, alert: t("invitations.throttled"), status: :see_other }

  def show
    authorize :invite_link, :show?

    @owner = owner
    render :unknown, status: :not_found unless @owner
  end

  def create
    authorize :invite_link, :create?

    result = Game::SendInvitation.new.call(player: current_player, recipient_token: params[:token])
    report_sent(result, to: helpers.friend_name(owner))
  end

  private
    def owner
      found = Accounts::PlayerByToken.call(params[:token])
      found unless found&.banned?
    end
end

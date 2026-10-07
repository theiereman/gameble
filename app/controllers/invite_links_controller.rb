# A player's permanent invite link (CAP-10, AD-8, AD-15): /:locale/invite/:token
# carries the player's own token. Opening it is a read (AD-11): it names the
# owner and offers to send them an invitation. A visitor signs in first (the
# sign-in panel; SessionsController returns here afterwards). Sending is the
# POST, the same invitation as by code.
class InviteLinksController < ApplicationController
  include InvitationFeedback

  rate_limit to: 20, within: 1.minute, only: :create,
    by: -> { current_player&.id || request.remote_ip },
    with: -> { redirect_to friends_path, alert: t("invitations.throttled"), status: :see_other }

  # GET /:locale/invite/:token
  def show
    authorize :invite_link, :show?

    @owner = owner
    render :unknown, status: :not_found unless @owner
  end

  # POST /:locale/invite/:token
  def create
    authorize :invite_link, :create?

    result = Game::SendInvitation.new.call(player: current_player, recipient_token: params[:token])
    report_sent(result, to: owner&.persona_name.presence || t("friends.show.nameless"))
  end

  private
    # The link's owner, or nil when the token names nobody or a banned player.
    def owner
      found = Accounts::PlayerByToken.call(params[:token])
      found unless found&.banned?
    end
end

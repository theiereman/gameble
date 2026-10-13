class InviteLinksController < ApplicationController
  include InvitationFeedback

  rate_limit to: 20, within: 1.minute, only: :create,
    by: -> { current_player&.id || request.remote_ip },
    with: -> { redirect_to friends_path, alert: t("invitations.throttled"), status: :see_other }

  def show
    authorize :invite_link, :show?

    @owner = owner
    return render :unknown, status: :not_found unless @owner

    @relation = relation_to(@owner)
  end

  def create
    authorize :invite_link, :create?

    result = Game::SendInvitation.new.call(player: current_player, recipient_token: params[:token])
    report_sent(result)
  end

  private
    def owner
      found = Accounts::PlayerByToken.call(params[:token])
      found unless found&.banned?
    end

    def relation_to(owner)
      return if current_player.nil? || current_player.id == owner.id

      return :friends if Game::FriendshipBetween.call(current_player, owner)
      return if invited_by?(owner)

      :invited if Game::InvitationAwaiting.call(current_player, owner)
    end

    def invited_by?(owner)
      Game::InvitationsOf.call(current_player).received.any? { |row| row.player.id == owner.id }
    end
end

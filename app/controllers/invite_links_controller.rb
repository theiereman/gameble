class InviteLinksController < ApplicationController
  include InvitationFeedback

  throttle_player to: 20, only: :create, path: -> { friends_path }, alert: "invitations.throttled"

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

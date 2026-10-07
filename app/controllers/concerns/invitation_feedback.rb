module InvitationFeedback
  extend ActiveSupport::Concern

  private
    def report_sent(result, to:)
      if result.failure?
        flash[:invite_error] = Game::SendInvitation.failure_message(result.failure)
      elsif result.value!.status == "accepted"
        new_friend(result.value!.sender_id)
      else
        flash[:invite_sent] = t("invitations.sent", to:)
      end
      redirect_to friends_path, status: :see_other
    end

    def new_friend(player_id)
      flash[:toast_title] = t("invitations.new_friend.title")
      flash[:notice] = t("invitations.new_friend.text", name: helpers.friend_name(Accounts::PlayerById.call(player_id)))
    end
end

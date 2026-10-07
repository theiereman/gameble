# What the Friends screen says after an invitation was sent (EXPERIENCE.md,
# Invite code messages; Toast): the line under the field, green for a
# success and orange for a refusal, or the "NOUVEL AMI" toast when the
# invitation crossed one already received and the friendship was made.
# Shared by the code form and the invite link page.
module InvitationFeedback
  extend ActiveSupport::Concern

  private
    # `to` names who the invitation went to (a code or a name).
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
      name = Accounts::PlayerById.call(player_id)&.persona_name.presence || t("friends.show.nameless")
      flash[:toast_title] = t("invitations.new_friend.title")
      flash[:notice] = t("invitations.new_friend.text", name:)
    end
end

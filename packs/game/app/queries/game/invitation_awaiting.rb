module Game
  module InvitationAwaiting
    def self.call(sender, recipient)
      return false if sender.nil? || recipient.nil?

      Invitation.unanswered.exists?(sender_id: sender.id, recipient_id: recipient.id)
    end
  end
end

module Game
  class SendInvitation < Operation
    def call(player:, code: nil, recipient_token: nil)
      player = step require_player(player)
      recipient = step recipient_of(player, code, recipient_token)

      transaction do
        step not_friends(player, recipient)
        reverse = Invitation.pending.find_by(sender_id: recipient.id, recipient_id: player.id)
        next step(AcceptInvitation.new.call(player:, token: reverse.token)) if reverse

        step create_pending(player, recipient)
      end
    end

    private

    def recipient_of(player, code, token)
      by_link = !token.nil?
      recipient = by_link ? player_of_token(token) : player_of_code(code)
      return recipient if recipient.is_a?(Dry::Monads::Result)

      return Failure(by_link ? :own_link : :own_code) if recipient.id == player.id

      Success(recipient)
    end

    def player_of_code(code)
      code = code.to_s.strip.upcase
      return Failure(:invalid_format) unless FriendCode::FORMAT.match?(code)

      owner = FriendCode.where(code:).pick(:player_id)
      found = owner && Accounts::PlayerById.call(owner)
      found && !found.banned? ? found : Failure(:unknown_code)
    end

    def player_of_token(token)
      found = Accounts::PlayerByToken.call(token)
      found && !found.banned? ? found : Failure(:unknown_player)
    end

    def not_friends(player, recipient)
      FriendshipBetween.call(player, recipient) ? Failure(:already_friends) : Success()
    end

    def create_pending(player, recipient)
      return Failure(:already_sent) if Invitation.pending.exists?(sender_id: player.id, recipient_id: recipient.id)

      invitation = Invitation.transaction(requires_new: true) do
        Invitation.create!(sender_id: player.id, recipient_id: recipient.id)
      end
      publish(InvitationSent.new(data: { invitation_id: invitation.id, sender_id: player.id, recipient_id: recipient.id }),
        stream_name: stream_name(player.id))
      Success(invitation)
    rescue ActiveRecord::RecordNotUnique
      Failure(:already_sent)
    end
  end
end

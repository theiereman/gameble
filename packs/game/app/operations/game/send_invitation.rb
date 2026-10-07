module Game
  # Sends a friend invitation (CAP-10, AD-8): to the player who owns a friend
  # code (`code:`, typed in the Friends screen) or to the player whose invite
  # link was opened (`recipient_token:`, the player's token, AD-15). Exactly
  # one of the two.
  #
  # A code is trimmed and upcased, then checked against the code format
  # (:invalid_format). It refuses the player's own code or link (:own_code,
  # :own_link), a code nobody holds or a banned owner (:unknown_code), a
  # link of nobody or of a banned player (:unknown_player), a pair already
  # friends (:already_friends) and an invitation still pending (:already_sent).
  # When the recipient already invited the sender, both want it: that
  # invitation is accepted instead (the friendship is created) and the
  # result is that accepted invitation. Otherwise a pending invitation is
  # created and Game::InvitationSent is published, in one transaction.
  #
  #   Game::SendInvitation.new.call(player:, code: "8F2D-K9XM")
  #   # => Success(invitation) | Failure(:player_required) | Failure(:invalid_format) | Failure(:own_code)
  #   #    | Failure(:own_link) | Failure(:unknown_code) | Failure(:unknown_player) | Failure(:already_friends)
  #   #    | Failure(:already_sent)
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
      low, high = [ player.id, recipient.id ].minmax
      Friendship.exists?(low_player_id: low, high_player_id: high) ? Failure(:already_friends) : Success()
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

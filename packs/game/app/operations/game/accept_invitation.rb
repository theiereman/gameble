module Game
  # Accepts a friend invitation received (CAP-10, AD-8): the friendship is
  # created in the same transaction that marks the invitation accepted, and
  # Game::InvitationAccepted is published. The invitation is found by its
  # token (AD-15) and must be pending and addressed to the player, else
  # :not_found; a sender banned or deleted meanwhile also gives :not_found.
  # A friendship that exists already (a rerun, a crossing invitation) is
  # kept: the invitation is still closed as accepted.
  #
  #   Game::AcceptInvitation.new.call(player:, token:)
  #   # => Success(invitation) | Failure(:player_required) | Failure(:not_found)
  class AcceptInvitation < Operation
    def call(player:, token:)
      player = step require_player(player)

      transaction do
        invitation = step pending_for(player, token)
        low, high = [ invitation.sender_id, invitation.recipient_id ].minmax
        Friendship.insert({ low_player_id: low, high_player_id: high }, unique_by: %i[low_player_id high_player_id])
        invitation.update!(status: "accepted")
        step publish(InvitationAccepted.new(data: { invitation_id: invitation.id, sender_id: invitation.sender_id, recipient_id: player.id }),
          stream_name: stream_name(player.id))
        invitation
      end
    end

    private

    def pending_for(player, token)
      invitation = token.is_a?(String) ? Invitation.pending.lock.find_by(token:, recipient_id: player.id) : nil
      sender = invitation && Accounts::PlayerById.call(invitation.sender_id)
      sender && !sender.banned? && !sender.deleted? ? Success(invitation) : Failure(:not_found)
    end
  end
end

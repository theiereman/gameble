module Game
  class AcceptInvitation < Operation
    def call(player:, token:)
      player = step require_player(player)
      received = step received_by(player, token)

      invitation, already_friends = transaction do
        TradeLocks.players(received.sender_id, player.id)
        invitation = step pending_for(player, token)
        already_friends = friends?(invitation)
        close_pair(invitation)
        unless already_friends
          befriend(invitation)
          step publish(InvitationAccepted.new(data: { invitation_id: invitation.id, sender_id: invitation.sender_id, recipient_id: player.id }),
            stream_name: stream_name(player.id))
        end
        [ invitation, already_friends ]
      end
      step(already_friends ? Failure(:already_friends) : Success())
      invitation
    end

    private

    def received_by(player, token)
      invitation = token.is_a?(String) ? Invitation.pending.find_by(token:, recipient_id: player.id) : nil
      invitation ? Success(invitation) : Failure(:not_found)
    end

    def pending_for(player, token)
      invitation = Invitation.pending.lock.find_by(token:, recipient_id: player.id)
      sender = invitation && Accounts::PlayerById.call(invitation.sender_id)
      sender && !sender.removed? ? Success(invitation) : Failure(:not_found)
    end

    def pair(invitation)
      low, high = [ invitation.sender_id, invitation.recipient_id ].minmax
      { low_player_id: low, high_player_id: high }
    end

    def friends?(invitation)
      Friendship.exists?(pair(invitation))
    end

    def befriend(invitation)
      Friendship.insert(pair(invitation), unique_by: %i[low_player_id high_player_id])
    end

    def close_pair(invitation)
      Invitation.unanswered.between(invitation.sender_id, invitation.recipient_id).update_all(status: "accepted", updated_at: Time.current)
      invitation.reload
    end
  end
end

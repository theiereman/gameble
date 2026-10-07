module Game
  # Ignores a friend invitation received (CAP-10, AD-8): it is marked ignored
  # and creates nothing; the sender is not told. Found by its token (AD-15),
  # it must be pending and addressed to the player, else :not_found.
  #
  #   Game::IgnoreInvitation.new.call(player:, token:)
  #   # => Success(invitation) | Failure(:player_required) | Failure(:not_found)
  class IgnoreInvitation < Operation
    def call(player:, token:)
      player = step require_player(player)

      transaction do
        invitation = token.is_a?(String) ? Invitation.pending.lock.find_by(token:, recipient_id: player.id) : nil
        step(invitation ? Success() : Failure(:not_found))
        invitation.update!(status: "ignored")
        invitation
      end
    end
  end
end

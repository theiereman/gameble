module Accounts
  # Deletes the account of a player idle for Player::IDLE_PERIOD, as
  # Accounts::DeletePlayer deletes it at the player's request. Idleness, role
  # and standing are read again on the locked row: a player seen, banned,
  # deleted or made staff since they were picked is refused.
  #
  #   Accounts::DeleteInactivePlayer.new.call(player:, now: Time.current)
  #   # => Success(player) | Failure(:player_required | :no_longer_idle)
  class DeleteInactivePlayer < ApplicationOperation
    NO_LONGER_IDLE = Dry::Monads::Failure(:no_longer_idle)

    def call(player:, now:)
      player = step require_player(player)

      transaction do
        player.lock!("FOR NO KEY UPDATE")
        step require_idle(player, now)
        step DeletePlayer.new.call(player:)
      end
    end

    private

    def require_player(player)
      player.is_a?(Player) && player.persisted? ? Success(player) : Failure(:player_required)
    end

    def require_idle(player, now)
      Player.idle(now).exists?(id: player.id) ? Success(player) : NO_LONGER_IDLE
    end
  end
end

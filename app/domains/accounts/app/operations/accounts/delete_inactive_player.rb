module Accounts
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

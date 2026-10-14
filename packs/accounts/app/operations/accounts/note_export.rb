module Accounts
  class NoteExport < ApplicationOperation
    def call(player:, at:)
      player = step require_player(player)

      transaction do
        player.update!(last_exported_at: at)
        player
      end
    end

    private

    def require_player(player)
      player.is_a?(Player) && player.persisted? && !player.banned? && !player.deleted? ? Success(player) : Failure(:player_required)
    end
  end
end

module Accounts
  class RecordExport < ApplicationOperation
    def call(player:, at:, &build_file)
      player = step require_player(player)

      transaction do
        player.lock!("FOR NO KEY UPDATE")
        step require_player(player)
        step require_due(player, at)
        file = build_file.call
        player.update!(last_exported_at: at)
        DataExport.upsert({ player_id: player.id, file:, created_at: at, updated_at: at }, unique_by: :player_id)
        file
      end
    end

    private

    def require_player(player)
      player.is_a?(Player) && player.persisted? && !player.banned? && !player.deleted? ? Success(player) : Failure(:player_required)
    end

    def require_due(player, at)
      player.next_export_at(at) ? Failure(:export_too_soon) : Success(player)
    end
  end
end

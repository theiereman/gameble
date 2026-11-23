module Game
  module Market
    class RebuildWanted < Operation
      def call(player:)
        player = step require_account(player)
        PendingWantedRefresh.where(player_id: player.id).delete_all

        transaction do
          step lock_bank(player)
          RefreshWanted.call(player)
          player
        end
      end
    end
  end
end

module Game
  module Market
    class RebuildWanted < Operation
      def call(player:)
        player = step require_account(player)

        transaction do
          step lock_bank(player)
          PendingWantedRefresh.where(player_id: player.id).delete_all
          RefreshWanted.call(player)
          player
        end
      end
    end
  end
end

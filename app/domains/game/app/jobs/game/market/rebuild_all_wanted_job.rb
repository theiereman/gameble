module Game
  module Market
    class RebuildAllWantedJob < ActiveJob::Base
      queue_as :default

      def perform
        failed_player_ids = []
        Accounts::PlayersInBatches.call do |players|
          players.each do |player|
            RefreshWantedJob.refresh(player)
          rescue StandardError => error
            Rails.error.report(error, context: { player_id: player.id })
            failed_player_ids << player.id
          end
        end
        failed_player_ids
      end
    end
  end
end

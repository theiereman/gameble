module Game
  module Market
    class RebuildAllWantedJob < ActiveJob::Base
      queue_as :default

      def perform
        Accounts::PlayersInBatches.call do |players|
          players.each do |player|
            result = RebuildWanted.new.call(player:)
            result.value! unless result.failure? && result.failure == :player_required
          rescue StandardError => error
            Rails.error.report(error, context: { player_id: player.id })
          end
        end
      end
    end
  end
end

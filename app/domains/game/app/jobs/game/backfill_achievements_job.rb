module Game
  class BackfillAchievementsJob < ActiveJob::Base
    queue_as :default

    def perform
      Accounts::PlayersInBatches.call do |players|
        players.each do |player|
          GrantAchievementsJob.grant(player, retroactive: true)
        rescue StandardError => error
          Rails.error.report(error, context: { player_id: player.id })
        end
      end
    end
  end
end

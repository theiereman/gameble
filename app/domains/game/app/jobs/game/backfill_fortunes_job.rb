module Game
  class BackfillFortunesJob < ActiveJob::Base
    queue_as :default

    def self.players_out_of_tally
      opened = Pack.where.not(opened_at: nil).group(:player_id).count
      tallied = Fortune.all_time.pluck(:player_id, Arel.sql("regular_packs + bonus_packs + reward_packs")).to_h
      opened.count { |player_id, count| tallied[player_id] != count }
    end

    def perform
      Accounts::PlayersInBatches.call(include_banned: true) do |players|
        players.each do |player|
          result = RebuildFortune.new.call(player:)
          result.value! unless result.failure? && result.failure == :player_required
        rescue StandardError => error
          Rails.error.report(error, context: { player_id: player.id })
        end
      end
    end
  end
end

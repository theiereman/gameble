module Game
  class BackfillPlayerStatesJob < ActiveJob::Base
    queue_as :default

    def self.players_without_a_row
      Accounts::Player.where(deleted_at: nil).where.not(id: PlayerState.select(:player_id)).count
    end

    def perform
      Accounts::PlayersInBatches.call(include_banned: true) do |players|
        with_state = PlayerState.where(player_id: players.map(&:id)).pluck(:player_id).to_set
        players.each do |player|
          next if with_state.include?(player.id)

          result = CreatePlayerState.new.call(player:)
          result.value! unless left_meanwhile?(result)
        rescue StandardError => error
          Rails.error.report(error, context: { player_id: player.id })
        end
      end
    end

    private

    def left_meanwhile?(result)
      result.failure? && result.failure == :player_required
    end
  end
end

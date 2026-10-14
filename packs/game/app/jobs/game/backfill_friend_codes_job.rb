module Game
  class BackfillFriendCodesJob < ActiveJob::Base
    queue_as :default

    def self.players_without_a_code
      Accounts::Player.where(deleted_at: nil).where.not(id: FriendCode.select(:player_id)).count
    end

    def perform
      Accounts::PlayersInBatches.call(include_banned: true) do |players|
        with_code = FriendCode.where(player_id: players.map(&:id)).pluck(:player_id).to_set
        players.each do |player|
          next if with_code.include?(player.id)

          result = CreateFriendCode.new.call(player:)
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

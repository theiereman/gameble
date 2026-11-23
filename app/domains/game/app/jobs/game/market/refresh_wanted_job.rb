module Game
  module Market
    class RefreshWantedJob < ActiveJob::Base
      queue_as :default

      def perform(player_id)
        player = Accounts::PlayerById.call(player_id)
        return if player.nil? || player.deleted?

        result = RebuildWanted.new.call(player:)
        result.value! unless result.failure? && result.failure == :player_required
      end
    end
  end
end

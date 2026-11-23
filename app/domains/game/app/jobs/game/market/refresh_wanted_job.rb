module Game
  module Market
    class RefreshWantedJob < ActiveJob::Base
      queue_as :default
      retry_on ActiveRecord::Deadlocked, ActiveRecord::LockWaitTimeout, wait: :polynomially_longer, attempts: 5

      def self.refresh(player)
        result = RebuildWanted.new.call(player:)
        result.value! unless result.failure? && result.failure == :player_required
      end

      def perform(player_id)
        player = Accounts::PlayerById.call(player_id)
        self.class.refresh(player) unless player.nil? || player.deleted?
      end
    end
  end
end

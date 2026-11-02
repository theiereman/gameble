module Game
  module Handlers
    module PackOpened
      def self.call(event)
        WeeklyContribution.record_opening(event.data.fetch(:player_id), event.metadata[:timestamp] || Time.current)
        Fortune.record_opening(event.data.fetch(:pack_id))
      end
    end
  end
end

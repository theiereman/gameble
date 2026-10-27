module Game
  module Handlers
    module PackOpened
      def self.call(event)
        WeeklyContribution.record_opening(event.data.fetch(:player_id), event.metadata[:timestamp] || Time.current)
      end
    end
  end
end

module Game
  class DuelDeadlineJob < ActiveJob::Base
    queue_as :duels

    def perform(token, move_number)
      DuelDeadlines.settle(token, move_number)
    end
  end
end

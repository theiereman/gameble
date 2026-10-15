module Accounts
  class CloseWelcomeJob < ActiveJob::Base
    queue_as :default

    def perform(player_id)
      CloseWelcome.new.call(player_id:).value!
    end
  end
end

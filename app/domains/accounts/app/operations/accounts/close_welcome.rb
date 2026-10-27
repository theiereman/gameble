module Accounts
  class CloseWelcome < ApplicationOperation
    def call(player_id:)
      transaction do
        Player.in_good_standing.where(id: player_id, welcome_pending: true).update_all(welcome_pending: false).positive?
      end
    end
  end
end

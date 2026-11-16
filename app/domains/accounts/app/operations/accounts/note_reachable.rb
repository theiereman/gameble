module Accounts
  class NoteReachable < ApplicationOperation
    LEASE = 45.seconds

    def call(player_id:, at: Time.current)
      Player.in_good_standing.where(id: player_id).update_all(reachable_until: at + LEASE)
    end
  end
end

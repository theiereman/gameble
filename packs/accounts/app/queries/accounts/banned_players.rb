module Accounts
  # The banned players whose accounts still exist, the latest ban first, as
  # a relation to page.
  #
  #   Accounts::BannedPlayers.call.limit(50) # => [Accounts::Player, …]
  module BannedPlayers
    def self.call
      Player.where.not(banned_at: nil).where(deleted_at: nil).order(banned_at: :desc, id: :desc)
    end
  end
end

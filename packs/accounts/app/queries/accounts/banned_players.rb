module Accounts
  module BannedPlayers
    def self.call
      Player.where.not(banned_at: nil).where(deleted_at: nil).order(banned_at: :desc, id: :desc).to_a
    end
  end
end

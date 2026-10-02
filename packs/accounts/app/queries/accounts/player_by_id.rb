module Accounts
  # Reads one player by database id, for the web layer's signed-in player
  # (AD-3: reads go through queries owned by the pack). Nil when absent.
  module PlayerById
    def self.call(id)
      return nil if id.blank?

      Player.find_by(id: id)
    end
  end
end

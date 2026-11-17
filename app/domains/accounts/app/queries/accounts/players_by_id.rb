module Accounts
  module PlayersById
    def self.call(ids)
      Player.where(id: ids).to_a
    end
  end
end

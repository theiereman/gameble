module Accounts
  module IdlePlayers
    def self.call(now:)
      Player.idle(now)
    end
  end
end

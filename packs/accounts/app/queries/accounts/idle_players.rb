module Accounts
  # The players no signed-in visit has been seen from for Player::IDLE_PERIOD,
  # as a relation to walk in batches. Staff, banned and deleted accounts are
  # never idle.
  #
  #   Accounts::IdlePlayers.call(now: Time.current).in_batches(of: 100) { |players| … }
  module IdlePlayers
    def self.call(now:)
      Player.idle(now)
    end
  end
end

module Accounts
  module PushDevicesOf
    def self.call(player_ids)
      PushDevice.joins(:player).merge(Player.in_good_standing).where(player_id: player_ids).to_a
    end
  end
end

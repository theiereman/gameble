module Game
  module LatestBestCard
    def self.call(player, season:) = LatestGains.call(player, season:, limit: 1).first
  end
end

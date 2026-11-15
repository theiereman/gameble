module Game
  # The trades sub-tab a player last used: between friends until they open the market.
  module ExchangesTab
    TABS = %w[friends market].freeze
    DEFAULT = "friends".freeze

    def self.call(player)
      return DEFAULT if player.nil?

      PlayerState.where(player_id: player.id).pick(:exchanges_tab) || DEFAULT
    end
  end
end

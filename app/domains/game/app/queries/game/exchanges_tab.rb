module Game
  module ExchangesTab
    TABS = %w[market friends].freeze
    DEFAULT = "market".freeze

    def self.call(player)
      return DEFAULT if player.nil?

      PlayerState.where(player_id: player.id).pick(:exchanges_tab) || DEFAULT
    end
  end
end

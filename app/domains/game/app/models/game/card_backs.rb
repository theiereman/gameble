module Game
  module CardBacks
    STANDARD = "standard".freeze

    Back = Data.define(:key, :asset, :unlock)
    Unlock = Data.define(:kind, :target)

    CATALOGUE = [
      Back.new(key: STANDARD, asset: "back-#{STANDARD}", unlock: Unlock.new(kind: :always, target: nil))
    ].freeze

    BY_KEY = CATALOGUE.index_by(&:key).freeze
    KEYS = BY_KEY.keys.freeze

    ACTIVE_UNLOCKED_SQL = <<~SQL.squish.freeze
      JOIN game_card_back_unlocks AS unlocks
        ON unlocks.player_id = game_player_states.player_id AND unlocks.back = game_player_states.active_card_back
    SQL

    def self.find(key)
      BY_KEY[key.to_s]
    end

    def self.active_key(player)
      PlayerState.where(player_id: player.id).joins(ACTIVE_UNLOCKED_SQL).pick(:active_card_back) || STANDARD
    end
  end
end

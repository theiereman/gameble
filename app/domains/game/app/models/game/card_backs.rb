module Game
  module CardBacks
    STANDARD = "standard".freeze

    Back = Data.define(:key, :asset, :unlock)
    Unlock = Data.define(:kind, :target)

    THEME_KEYS = %w[
      souls_like metroidvania roguelike deckbuilder cosy farming horror zombies pirates space cyberpunk fps
      third_person_shooter platformer puzzle racing sports strategy rpg survival city_builder visual_novel
      point_and_click adventure fighting stealth rhythm shoot_em_up hack_and_slash post_apocalyptic war medieval
      anime sandbox tower_defense mystery simulation comedy open_world idle walking_simulator vr adult
    ].freeze
    HALL_OF_FAME_KEYS = %w[intouchables pepites mal-aimes phenomenes].freeze

    SET_KEYS = { "theme" => THEME_KEYS, "hall_of_fame" => HALL_OF_FAME_KEYS }.freeze

    SET_BACKS = SET_KEYS.flat_map do |kind, keys|
      keys.map do |key|
        Back.new(key: "set-#{kind}-#{key}", asset: "back-#{kind}-#{key}", unlock: Unlock.new(kind: :set_tier, target: [ kind, key ]))
      end
    end.freeze

    CATALOGUE = [
      Back.new(key: STANDARD, asset: "back-#{STANDARD}", unlock: Unlock.new(kind: :always, target: nil)),
      *SET_BACKS
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

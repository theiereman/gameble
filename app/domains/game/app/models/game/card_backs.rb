module Game
  module CardBacks
    STANDARD = "standard".freeze

    KEYS = [ STANDARD ].freeze

    def self.active_key(_player)
      STANDARD
    end
  end
end

module Game
  # The card backs a booster can show (AD-25). Only `standard` exists for
  # now; epic 9 adds the others and the player's active back. A pack keeps
  # the key of the back the player had on when it was opened (Pack#card_back).
  #
  #   Game::CardBacks.active_key(player) # => "standard"
  module CardBacks
    STANDARD = "standard".freeze

    KEYS = [ STANDARD ].freeze

    # The back the player has on. Always `standard` until epic 9 reads it
    # from the player's game_player_states column (AD-25).
    def self.active_key(_player)
      STANDARD
    end
  end
end

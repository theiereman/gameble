module Game
  module Market
    # What a player can still mint today under the settings' daily cap, never below zero.
    module CapLeft
      def self.call(player_id, settings:, now: Time.current)
        [ settings.daily_cap - MintedToday.call(player_id, now:), 0 ].max
      end
    end
  end
end

module Game
  # When the packs of a player's bank not available yet come (R4, AD-23):
  # their availability times at `now`, ascending, empty when every one is
  # available. Regular packs only, as Game::BankSummary's next_available_at,
  # which is the first of them.
  #
  #   Game::BankSchedule.call(player) # => [ Time, Time, … ]
  module BankSchedule
    def self.call(player, now: Time.current)
      Pack.bank(player.id).where.not(available_at: ..now).order(:available_at).pluck(:available_at)
    end
  end
end

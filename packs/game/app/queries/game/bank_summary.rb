module Game
  # What a player's chest shows (R9): the packs they can open now, of every
  # kind. { available: n }
  module BankSummary
    def self.call(player, now: Time.current)
      { available: Pack.where(player_id: player.id).available(now).count }
    end
  end
end

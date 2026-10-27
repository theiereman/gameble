module Game
  module BankSchedule
    def self.call(player, now: Time.current)
      Pack.bank(player.id).where.not(available_at: ..now).order(:available_at).pluck(:available_at)
    end
  end
end

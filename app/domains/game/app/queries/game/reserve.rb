module Game
  module Reserve
    FULL = 10

    def self.count(player_id, now: Time.current)
      Pack.where(player_id:).available(now).count
    end

    def self.full?(count)
      count >= FULL
    end
  end
end

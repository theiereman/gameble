module Game
  module TopUpBank
    def self.call(player_id:, now:, pool: DrawPool.current, random: SecureRandom)
      bank = Pack.bank(player_id)
      return 0 unless bank.count < Pack::BANK_SIZE

      start = [ now, bank.maximum(:available_at) ].compact.max
      insert(player_id, [ start + Pack::INTERVAL ], random, pool)
    end

    def self.heal(player_id:, now:, random: SecureRandom)
      missing = Pack::BANK_SIZE - Pack.bank(player_id).count
      return 0 unless missing.positive?

      insert(player_id, [ now ] * missing, random, DrawPool.current)
    end

    def self.insert(player_id, times, random, pool)
      return 0 if pool.nil?

      Pack.insert_all!(times.map do |available_at|
        Pack.row(player_id:, kind: :regular, season_id: pool.season_id,
          card_season_ids: Draw.pack(odds: DrawOdds::REGULAR, size: Pack::SIZE, random:, pool:), available_at:)
      end)
      times.size
    end
    private_class_method :insert
  end
end

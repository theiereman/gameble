module Game
  module Reserve
    FULL = 10

    Counts = Data.define(:standard, :special) do
      def openable = standard + special
    end

    def self.counts(player_id, now: Time.current)
      by_kind = Pack.where(player_id:).available(now).reorder(nil).group(:kind).count
      standard = by_kind.fetch("regular", 0)
      Counts.new(standard:, special: by_kind.values.sum - standard)
    end

    def self.full?(count)
      count >= FULL
    end
  end
end

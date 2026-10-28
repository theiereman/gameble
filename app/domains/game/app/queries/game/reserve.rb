module Game
  module Reserve
    FULL = 10
    KINDS = { "standard" => %w[regular], "special" => %w[bonus reward] }.freeze
    NAMES = KINDS.keys.freeze

    Counts = Data.define(:standard, :special, :next_special_kind) do
      def openable = standard + special
    end

    def self.counts(player_id, now: Time.current)
      rows = Pack.where(player_id:).available(now).reorder(nil).group(:kind)
        .pluck(:kind, Arel.sql("COUNT(*)"), Arel.sql("MIN(available_at)"))
      standard, specials = rows.partition { |kind,| KINDS.fetch("standard").include?(kind) }
      Counts.new(standard: standard.sum { |_, count,| count }, special: specials.sum { |_, count,| count }, next_special_kind: specials.min_by(&:last)&.first)
    end

    def self.of(name)
      name.to_s if NAMES.include?(name.to_s)
    end

    def self.available(player_id, name, now: Time.current)
      Pack.where(player_id:).available(now).where(kind: KINDS.fetch(name.to_s))
    end

    def self.full?(count)
      count >= FULL
    end
  end
end

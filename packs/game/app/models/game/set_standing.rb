module Game
  SetStanding = Data.define(:set_id, :held, :total, :tiers, :just, :reached_now, :gained_at) do
    def self.unstarted(set_id:, total:, tiers:)
      new(set_id:, held: 0, total:, tiers:, just: false, reached_now: false, gained_at: nil)
    end

    def self.measured(set_id:, held:, total:, tiers:)
      new(set_id:, held:, total:, tiers:, just: false, reached_now: false, gained_at: nil)
    end

    def thresholds
      Catalog::SetTier::TIERS.filter_map do |tier|
        required = tier == "complete" ? tiers.fetch(tier, total) : tiers[tier]
        [ tier, required ] if required&.positive?
      end
    end

    def reached_tier
      thresholds.reverse.find { |_tier, required| required <= held }&.first
    end

    def next_tier
      thresholds.find { |_tier, required| required > held }&.first
    end

    def next_required
      thresholds.find { |_tier, required| required > held }&.last
    end

    def missing
      next_required && next_required - held
    end

    def complete?
      total.positive? && held >= total
    end

    def tiered?
      tiers.key?("bronze")
    end

    def started?
      held.positive?
    end

    def in_progress?
      started? && (held >= 2 || !reached_tier.nil?) && (!complete? || reached_now)
    end

    def share
      total.positive? ? held.fdiv(total) : 0.0
    end

    def tier_reached?(tier)
      required = thresholds.to_h[tier]
      !required.nil? && required <= held
    end
  end
end

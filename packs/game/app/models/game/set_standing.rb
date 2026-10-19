module Game
  SetStanding = Data.define(:set_id, :held, :total, :tiers, :just, :reached_now, :gained_at) do
    def self.unstarted(set_id:, total:, tiers:)
      new(set_id:, held: 0, total:, tiers:, just: false, reached_now: false, gained_at: nil)
    end

    def self.measured(set_id:, held:, total:, tiers:)
      new(set_id:, held:, total:, tiers:, just: false, reached_now: false, gained_at: nil)
    end

    # The set's tiers as [tier, required] pairs, the fewest cards first;
    # the set's size completes it unless its tiers say otherwise.
    def thresholds
      tiers.reverse_merge(Catalog::SetTier::COMPLETE => total)
        .select { |_tier, required| required&.positive? }
        .sort_by { |tier, required| [ required, Catalog::SetTier::TIERS.index(tier) ] }
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
      tiers.keys.any? { |tier| tier != Catalog::SetTier::COMPLETE }
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

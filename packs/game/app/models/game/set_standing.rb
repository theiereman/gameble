module Game
  SetStanding = Data.define(:set_id, :held, :total, :tiers, :just, :reached_now, :gained_at, :completed_at) do
    def self.unstarted(set_id:, total:, tiers:)
      new(set_id:, held: 0, total:, tiers:, just: false, reached_now: false, gained_at: nil, completed_at: nil)
    end

    def self.measured(set_id:, held:, total:, tiers:)
      new(set_id:, held:, total:, tiers:, just: false, reached_now: false, gained_at: nil, completed_at: nil)
    end

    # The set's tiers as [tier, required] pairs, the fewest cards first;
    # the set's size completes it unless its tiers say otherwise, and a set
    # too small for tiers has completion alone.
    def thresholds
      tiers.reverse_merge(Catalog::SetTier::COMPLETE => total)
        .select { |tier, required| required&.positive? && (tier == Catalog::SetTier::COMPLETE || Catalog::TierTable.tiered?(total)) }
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

    def started?
      held.positive?
    end

    def in_progress?
      started? && (held >= 2 || !reached_tier.nil?) && (!complete? || reached_now)
    end

    def share
      total.positive? ? held.fdiv(total) : 0.0
    end
  end
end

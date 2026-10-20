module SetRowsHelper
  # The notches of an earlier season's metal tier; a rank has its own mark.
  NOTCHES = { "bronze" => 1, "silver" => 2, "gold" => 3 }.freeze

  def set_kind_name(kind)
    t("library.set_kinds.#{kind}")
  end

  def set_tier_name(tier)
    t("library.set_progress.tiers.#{tier}")
  end

  def set_progress_sentence(set, standing)
    parts = [ SetLabel.for(set), set_kind_name(set.kind).downcase,
      t("library.set_progress.count", count: standing.held, owned: number_with_delimiter(standing.held), total: number_with_delimiter(standing.total)) ]
    parts.concat(standing.complete? ? [ t("library.set_progress.complete") ] : tier_words(standing))
    parts.join(", ")
  end

  def set_album_value_text(standing)
    count = t("library.set_progress.count", count: standing.held, owned: number_with_delimiter(standing.held), total: number_with_delimiter(standing.total))
    tier = if standing.complete?
      t("library.set_progress.complete")
    elsif before_completion?(standing.reached_tier)
      t("library.set_progress.tier", tier: set_tier_name(standing.reached_tier).downcase)
    end
    [ count, tier ].compact.join(", ")
  end

  def set_tier_mark(standing)
    if standing.complete?
      tag.span(class: "set-tier set-tier--complete") { tag.span(class: "set-tier__stamp") + tag.span(set_tier_name("complete")) }
    elsif before_completion?(standing.reached_tier)
      tier = standing.reached_tier
      tag.span(class: "set-tier set-tier--#{tier}") { safe_join([ *reached_rank_lead(tier), metal_notches(tier), tag.span(set_tier_name(tier)) ].compact) }
    end
  end

  # Whether the set's bar carries ticks: a tier before completion, not yet complete.
  def set_tier_ticks?(standing)
    !standing.complete? && tick_thresholds(standing).any?
  end

  # One tick per tier before completion, at its share of the set, its mark
  # under it; with `figures`, the count each tier asks under the mark.
  def set_tier_ticks(standing, figures: false)
    return unless set_tier_ticks?(standing)

    safe_join(tick_thresholds(standing).flat_map do |tier, required|
      reached = required <= standing.held
      at = tick_at(required, standing.total)
      tick = tag.span(class: [ "set-row__tick", "set-row__tick--#{tier}", ("is-reached" if reached) ], data: { tier_at: at }) do
        tag.span(tier_tick_mark(tier), class: "set-row__tick-mark")
      end
      next [ tick ] unless figures

      [ tick, tag.span(number_with_delimiter(required), class: [ "set-album__figure", ("is-reached" if reached) ], data: { tier_at: at }) ]
    end)
  end

  def set_notches(count)
    tag.span(class: "set-notches") { safe_join(Array.new(count) { tag.i }) }
  end

  # A rank's insignia, drawn one CSS pixel per art pixel unless `fine: false`.
  def rank_mark(tier, fine: true, **attrs)
    pixel_icon("rank-#{tier}", **attrs.merge(class: [ "rank-mark", "rank-mark--#{tier}", ("rank-mark--fine" if fine), attrs[:class] ].compact.join(" ")))
  end

  def rank_tier?(tier)
    Catalog::TierTable::RANKS.include?(tier)
  end

  private

    def before_completion?(tier)
      tier.present? && tier != Catalog::SetTier::COMPLETE
    end

    def tick_thresholds(standing)
      standing.thresholds.select { |tier, _required| before_completion?(tier) }
    end

    def tick_at(required, total)
      required.fdiv(total).round(4).to_s
    end

    def tier_tick_mark(tier)
      rank_tier?(tier) ? rank_mark(tier) : set_notches(NOTCHES.fetch(tier))
    end

    def reached_rank_lead(tier)
      [ pixel_icon("check", class: "set-tier__check"), rank_mark(tier) ] if rank_tier?(tier)
    end

    def metal_notches(tier)
      set_notches(NOTCHES.fetch(tier)) if NOTCHES.key?(tier)
    end

    def tier_words(standing)
      reached = standing.reached_tier
      upcoming = standing.next_tier
      words = []
      words << t("library.set_progress.tier", tier: set_tier_name(reached).downcase) if reached
      if before_completion?(upcoming)
        words << t("library.set_progress.next", tier: set_tier_name(upcoming).downcase, required: number_with_delimiter(standing.next_required))
      end
      words
    end
end

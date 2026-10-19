module SetRowsHelper
  # The notches of an earlier season's metal tier; a rank shows its name alone.
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
      tag.span(class: "set-tier set-tier--#{tier}") { safe_join([ metal_notches(tier), tag.span(set_tier_name(tier)) ].compact) }
    end
  end

  def set_tier_ticks(standing)
    return unless metal_tiers?(standing)

    safe_join(NOTCHES.map do |tier, count|
      tag.span(class: [ "set-row__tick", "set-row__tick--#{tier}", ("is-reached" if standing.tier_reached?(tier)) ]) { set_notches(count) }
    end)
  end

  def set_notches(count)
    tag.span(class: "set-notches") { safe_join(Array.new(count) { tag.i }) }
  end

  private

    def before_completion?(tier)
      tier.present? && tier != Catalog::SetTier::COMPLETE
    end

    def metal_tiers?(standing)
      standing.tiers.keys.intersect?(NOTCHES.keys)
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

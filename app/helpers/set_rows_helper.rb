module SetRowsHelper
  NOTCHES = { "bronze" => 1, "silver" => 2, "gold" => 3 }.freeze

  PathNode = Data.define(:tier, :required, :state, :lit)

  def set_kind_name(kind)
    t("library.set_kinds.#{kind}")
  end

  def set_tier_name(tier)
    t("library.set_progress.tiers.#{tier}")
  end

  def set_label_sentence(set)
    [ SetLabel.for(set), set_kind_name(set.kind).downcase ].join(", ")
  end

  def set_progress_sentence(set, standing)
    parts = [ set_label_sentence(set),
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

  def set_tier_ticks?(standing)
    !standing.complete? && tick_thresholds(standing).any?
  end

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

  def rank_mark(tier, fine: true, **attrs)
    pixel_icon("rank-#{tier}", **attrs.merge(class: [ "rank-mark", "rank-mark--#{tier}", ("rank-mark--fine" if fine), attrs[:class] ].compact.join(" ")))
  end

  def rank_tier?(tier)
    Catalog::TierTable::RANKS.include?(tier)
  end

  def set_rank_chip(standing)
    tier = standing.reached_tier
    return tag.span(t("library.set_tile.no_tier"), class: "set-chip set-chip--rank set-chip--none") if tier.nil?

    set_tier_chip(tier, class: "set-chip--rank")
  end

  def set_tier_chip(tier, **attrs)
    tag.span(set_tier_name(tier), class: [ "set-chip", "tier-tone--#{tier}", attrs[:class] ])
  end

  def set_goal_line(standing)
    return t("library.set_tile.complete") if standing.complete?
    return if standing.missing.nil?

    t("library.set_tile.next_html", count: standing.missing, missing: number_with_delimiter(standing.missing), tier: set_tier_chip(standing.next_tier))
  end

  def set_tier_path(standing)
    upcoming = standing.next_tier
    standing.thresholds.each_with_index.map do |(tier, required), index|
      state = if required <= standing.held then :reached elsif tier == upcoming then :next else :later end
      PathNode.new(tier:, required:, state:, lit: path_lit(standing.held, index.zero? ? nil : standing.thresholds[index - 1].last, required))
    end
  end

  def set_gained_ago(time, now: Time.current)
    minutes = [ ((now - time) / 60).floor, 1 ].max
    if minutes < 60
      t("library.set_tile.gained.minutes", count: minutes)
    elsif minutes < 24 * 60
      t("library.set_tile.gained.hours", count: minutes / 60)
    else
      t("library.set_tile.gained.days", count: minutes / (24 * 60))
    end
  end

  private

    def before_completion?(tier)
      tier.present? && tier != Catalog::SetTier::COMPLETE
    end

    def tick_thresholds(standing)
      standing.thresholds.select { |tier, _required| before_completion?(tier) }
    end

    def path_lit(held, previous, required)
      return if previous.nil?
      return held >= required ? 100 : 0 unless required > previous

      (100 * (held - previous).clamp(0, required - previous) / (required - previous).to_f).round
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

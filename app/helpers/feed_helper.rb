module FeedHelper
  TIER_NOTCHES = { "bronze" => 1, "silver" => 2, "gold" => 3 }.freeze

  def feed_sentence(item, card, partner_card = nil, set = nil)
    return feed_set_sentence(item, set) if item.entry.kind == "set"

    words = { name: feed_name(item.player), card: tag.strong(card.title) }
    case item.entry.kind
    when "discovery" then t("feeds.show.discovered_html", **words)
    when "repost" then t("feeds.show.reposted_html", **words)
    when "trade" then t("feeds.show.traded_html", **words, partner: feed_name(item.partner), partner_card: tag.strong(partner_card.title))
    else t("feeds.show.pulled_html", **words)
    end
  end

  def feed_rarity_name(card)
    t("catalog.rarity.#{card.rarity}")
  end

  def feed_tier_tag(tier, surface_class:)
    mark = if tier == Catalog::SetTier::COMPLETE
      tag.span(class: "feed__tier-stamp")
    elsif TIER_NOTCHES.key?(tier)
      tag.span(class: "feed__tier-notches") { safe_join(Array.new(TIER_NOTCHES.fetch(tier)) { tag.i }) }
    elsif rank_tier?(tier)
      rank_mark(tier, class: "feed__tier-rank")
    end
    tag.span(class: [ surface_class, "feed__tier", "feed__tier--#{tier}" ]) do
      tag.span(mark, class: "feed__tier-mark") + tag.span(feed_tier_name(tier))
    end
  end

  private

  def feed_set_sentence(item, set)
    words = { name: feed_name(item.player), set: tag.strong(SetLabel.for(set)) }
    tier = item.entry.tier
    if item.entry.set_count > 1
      t("feeds.show.sets_reached_html", **words, count: item.entry.set_count, tier: feed_tier_name(tier).upcase)
    else
      t("feeds.show.set_reached.#{tier}_html", **words)
    end
  end

  def feed_tier_name(tier)
    t("feeds.show.tiers.#{tier}")
  end

  def feed_name(player)
    tag.strong(player.persona_name.presence || t("feeds.show.nameless"))
  end
end

module FeedHelper
  TIER_NOTCHES = { "bronze" => 1, "silver" => 2, "gold" => 3 }.freeze

  def feed_sentence(item, card, partner_card = nil, set = nil, links: true, titles: false)
    return feed_set_sentence(item, set, links:, titles:) if item.entry.kind == "set"

    words = { name: feed_name(item.player, item.player_title, links:, titles:), card: feed_game(card, links:) }
    case item.entry.kind
    when "discovery" then t("feeds.show.discovered_html", **words)
    when "repost" then t("feeds.show.reposted_html", **words)
    when "trade" then t("feeds.show.traded_html", **words, partner: feed_name(item.partner, item.partner_title, links:, titles:), partner_card: feed_game(partner_card, links:))
    else t("feeds.show.pulled_html", **words)
    end
  end

  def feed_chip_link(label, path, current:, classes:)
    link_to path, class: [ classes, "filter-chip" ], aria: { current: ("true" if current) } do
      tag.span(label, class: "filter-chip__text")
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

  def feed_set_sentence(item, set, links:, titles:)
    words = { name: feed_name(item.player, item.player_title, links:, titles:), set: tag.strong(SetLabel.for(set)) }
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

  def feed_name(player, title, links:, titles:)
    name = player.persona_name.presence
    shown = if name.nil? then tag.strong(t("feeds.show.nameless"))
    elsif links then link_to(name, brother_path(token: player.token), class: "feed__name", data: { turbo_prefetch: false })
    else tag.strong(name)
    end
    titles ? safe_join([ shown, active_title_tag(title, class_name: "feed__title") ].compact, " ") : shown
  end

  def feed_game(card, links:)
    return tag.strong(card.title) unless links

    link_to card.title, card_path(slug: card.id), class: "feed__game", data: { turbo_prefetch: false }
  end
end

module FeedHelper
  TIER_NOTCHES = { "bronze" => 1, "silver" => 2, "gold" => 3 }.freeze

  def feed_sentence(item, card, partner_card = nil, set = nil, links: true, titles: false, viewer: nil)
    return feed_set_sentence(item, set, links:, titles:) if item.entry.kind == "set"
    return feed_verdict_sentence(item, links:, titles:) if item.entry.kind == "verdict"
    return feed_sale_sentence(item, card, links:, titles:, viewer:) if item.entry.kind == "sale"

    words = { name: feed_name(item.player, item.player_title, links:, titles:), card: feed_game(card, links:) }
    case item.entry.kind
    when "discovery" then t("feeds.show.discovered_html", **words)
    when "repost" then t("feeds.show.reposted_html", **words)
    when "trade" then t("feeds.show.traded_html", **words, partner: feed_name(item.partner, item.partner_title, links:, titles:), partner_card: feed_game(partner_card, links:))
    else t("feeds.show.pulled_html", **words)
    end
  end

  def feed_byline(item, viewer: nil)
    return feed_sale_buyer(item, links: true, titles: true, viewer:) if item.entry.kind == "sale"

    feed_name(item.player, item.player_title, links: true, titles: true)
  end

  def feed_headline(item, card, partner_card, set)
    kicker, title = feed_headline_parts(item, card, partner_card, set)
    tag.p(class: [ "feed__headline", ("feed__headline--discovery" if item.entry.kind == "discovery") ]) do
      tag.span(kicker, class: "feed__headline-kicker") + tag.span(title, class: "feed__headline-title")
    end
  end

  def feed_types_sheet_id = "feed-types"

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

  def feed_headline_parts(item, card, partner_card, set)
    case item.entry.kind
    when "set" then [ feed_set_kicker(item.entry), SetLabel.for(set) ]
    when "verdict" then [ t("feeds.show.headline.verdict"), feed_register_link(t("feeds.show.headline.verdict_title")) ]
    when "trade"
      partner = feed_name(item.partner, nil, links: true, titles: false)
      [ t("feeds.show.headline.traded_html", partner:), t("feeds.show.headline.trade_html", card: feed_game(card, links: true), partner_card: feed_game(partner_card, links: true)) ]
    when "discovery" then [ t("feeds.show.first_discovery"), feed_game(card, links: true) ]
    when "repost" then [ t("feeds.show.headline.reposted"), feed_game(card, links: true) ]
    when "sale" then [ t("feeds.show.headline.bought"), feed_game(card, links: true) ]
    else [ t("feeds.show.headline.pulled"), feed_game(card, links: true) ]
    end
  end

  def feed_set_kicker(entry)
    return t("feeds.show.headline.sets_reached", count: entry.set_count) if entry.set_count > 1

    t("feeds.show.headline.set_reached.#{entry.tier}")
  end

  def feed_register_link(label)
    link_to(label, fortune_register_path(period: "last_week"), class: "feed__game", data: { turbo_prefetch: false })
  end

  def feed_set_sentence(item, set, links:, titles:)
    words = { name: feed_name(item.player, item.player_title, links:, titles:), set: tag.strong(SetLabel.for(set)) }
    tier = item.entry.tier
    if item.entry.set_count > 1
      t("feeds.show.sets_reached_html", **words, count: item.entry.set_count, tier: feed_tier_name(tier).upcase)
    else
      t("feeds.show.set_reached.#{tier}_html", **words)
    end
  end

  def feed_sale_sentence(item, card, links:, titles:, viewer:)
    name = feed_sale_buyer(item, links:, titles:, viewer:)
    t("feeds.show.sale_html", name:, card: feed_game(card, links:), amount: render(PicoinAmountComponent.new(amount: item.price)))
  end

  def feed_sale_buyer(item, links:, titles:, viewer:)
    buyer = render(PlayerNameComponent.new(player: item.player, viewer:, linked: links))
    titles ? safe_join([ buyer, feed_rank(item.player_title) ].compact, " ") : buyer
  end

  def feed_verdict_sentence(item, links:, titles:)
    label = t("feeds.show.verdict_register")
    register = links ? feed_register_link(label) : tag.strong(label)
    t("feeds.show.verdict_html", name: feed_name(item.player, item.player_title, links:, titles:), register:)
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
    titles ? safe_join([ shown, feed_rank(title) ].compact, " ") : shown
  end

  def feed_rank(title)
    return unless title

    rank = tag.span(class: "feed__rank-name") do
      safe_join([ (rank_mark(title.rank, class: "feed__rank-mark") if rank_tier?(title.rank)), t("profile_titles.ranks.#{title.rank}") ].compact)
    end
    tag.span(class: [ "profile-title", "feed__rank", "feed__rank--#{title.rank}" ]) do
      safe_join([ rank, tag.span("·", class: "feed__rank-dot"), tag.span(SetLabel.for(title), class: "feed__rank-set") ], " ")
    end
  end

  def feed_game(card, links:)
    return tag.strong(card.title) unless links

    link_to card.title, card_path(slug: card.id), class: "feed__game", data: { turbo_prefetch: false }
  end
end

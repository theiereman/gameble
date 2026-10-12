module FeedHelper
  def feed_sentence(item, card, partner_card = nil)
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

  private

  def feed_name(player)
    tag.strong(player.persona_name.presence || t("feeds.show.nameless"))
  end
end

module FeedHelper
  def feed_sentence(item, card)
    words = { name: tag.strong(item.player.persona_name.presence || t("feeds.show.nameless")), card: tag.strong(card.title) }
    case item.entry.kind
    when "discovery" then t("feeds.show.discovered_html", **words)
    when "repost" then t("feeds.show.reposted_html", **words)
    else t("feeds.show.pulled_html", **words)
    end
  end

  def feed_rarity_name(card)
    t("catalog.rarity.#{card.rarity}")
  end
end

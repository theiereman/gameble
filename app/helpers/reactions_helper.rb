module ReactionsHelper
  def reaction_count_text(count)
    count.positive? ? count.to_s : ""
  end

  def reaction_icon(kind, class_name: "feed__reaction-icon")
    image_tag vite_asset_path("images/reactions/#{kind.dasherize}.png"), alt: "", width: 20, height: 20, class: class_name
  end

  def reaction_reactors(names, count)
    others = count - names.size
    return t("reactions.who.players", count:) if names.empty?
    return names.to_sentence(two_words_connector: t("reactions.who.and"), last_word_connector: t("reactions.who.and")) if others.zero?

    t("reactions.who.and_others", names: names.join(", "), count: others)
  end
end

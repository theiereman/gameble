# The words and links of a card's detail and of the links leading to it
# (CAP-7, story 4.3).
module CardDetailsHelper
  # The game's Steam store page, in French on a French page (Steam reads
  # `l=french`); any query the address already has is kept.
  def card_detail_store_url(url)
    return url unless I18n.locale.to_s == "fr"

    uri = URI.parse(url)
    query = URI.decode_www_form(uri.query.to_s).reject { |key, _| key == "l" } << [ "l", "french" ]
    uri.query = URI.encode_www_form(query)
    uri.to_s
  rescue URI::InvalidURIError
    url
  end

  # The name of a link to a card's detail: "Portal, Amethyst, season 1".
  def card_detail_open_label(view, strings)
    t("card_details.open", title: view.title, rarity: strings.rarity_name(view.rarity), season: view.season_number)
  end

  # A card's face or empty slot, leading to its detail in its own season.
  def link_to_card_detail(view, strings, &)
    link_to(card_season_path(slug: view.id, number: view.season_number), class: "card-link",
      aria: { label: card_detail_open_label(view, strings) }, data: { turbo_prefetch: false }, &)
  end
end

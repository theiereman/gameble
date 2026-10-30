module CardDetailsHelper
  def card_preview_title(view)
    t("card_details.preview.title", title: view.title, rarity: CardStrings.new.rarity_name(view.rarity))
  end

  def card_share_image_alt(view)
    t("card_details.preview.image_alt", title: view.title, rarity: CardStrings.new.rarity_name(view.rarity))
  end

  def card_public_url(view)
    public_url_for(card_season_path(slug: view.id, number: view.season_number))
  end

  def card_share_image_url(token)
    public_url_for(share_image_path(token:, locale: nil))
  end

  def card_detail_store_url(url)
    return url unless I18n.locale.to_s == "fr"

    uri = URI.parse(url)
    query = URI.decode_www_form(uri.query.to_s).reject { |key, _| key == "l" } << [ "l", "french" ]
    uri.query = URI.encode_www_form(query)
    uri.to_s
  rescue URI::InvalidURIError
    url
  end

  def card_detail_steam_reviews(reviews)
    t("card_details.steam_reviews", count: reviews.count, reviews: number_with_delimiter(reviews.count),
      percent: number_to_percentage(reviews.positive_percent.floor, precision: 0))
  end

  def card_detail_pioneer_date(day)
    format = day.day == 1 ? :long_day_first : :long_day
    t("card_details.pioneer.dated", date: l(day, format:))
  end

  def card_detail_edition_lines(editions, strings)
    editions.group_by(&:first).map do |rarity, held|
      seasons = held.map { |_, season_number, _| t("card_details.season_short", number: season_number) }
      t("card_details.editions_line", rarity: strings.rarity_name(rarity), seasons: seasons.join(", "))
    end
  end

  def card_detail_open_label(view, strings, owned: true)
    t(owned ? "card_details.open" : "card_details.open_not_owned",
      title: view.title, year: view.year, rarity: strings.rarity_name(view.rarity), season: view.season_number)
  end

  def link_to_card_detail(view, strings:, context: {}, number: view.season_number, owned: true, &)
    link_to(card_detail_path(view.id, number, context), class: "card-link", aria: { label: card_detail_open_label(view, strings, owned:) },
      data: { turbo_prefetch: false }, &)
  end

  def card_detail_path(slug, number, context = {})
    card_season_path(slug:, number:, **context)
  end

  def card_top_rarity?(rarity)
    rarity.to_s.in?(%w[epic legendary])
  end

  def card_rays(rarity)
    return unless card_top_rarity?(rarity)

    tag.span(nil, class: [ "card-rays", "card-rays--#{rarity}" ], aria: { hidden: true })
  end
end

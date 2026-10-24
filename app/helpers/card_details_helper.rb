# The words and links of a card's detail and of the links leading to it
# (with what it browses: a grid, an opened pack, a set), and its link
# previews.
module CardDetailsHelper
  # A card's title in its page's and its previews' language: "Portal —
  # Epic".
  def card_preview_title(view)
    t("card_details.preview.title", title: view.title, rarity: CardStrings.new.rarity_name(view.rarity))
  end

  # The absolute, season-qualified URL of a card-season's page on the
  # public base: its share link, og:url and canonical link alike.
  def card_public_url(view)
    public_url_for(card_season_path(slug: view.id, number: view.season_number))
  end

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

  # "93% positive · 12,345 reviews", in the locale's number format; the
  # share is rounded down, so a few negative reviews never read as 100%.
  def card_detail_steam_reviews(reviews)
    t("card_details.steam_reviews", count: reviews.count, reviews: number_with_delimiter(reviews.count),
      percent: number_to_percentage(reviews.positive_percent.floor, precision: 0))
  end

  # "on March 1, 2026" / "le 1er mars 2026": the first of a month is
  # an ordinal in French.
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

  # "Portal, 2007, Epic, season 1", and ", not owned" after it for a card
  # its viewer does not hold.
  def card_detail_open_label(view, strings, owned: true)
    t(owned ? "card_details.open" : "card_details.open_not_owned",
      title: view.title, year: view.year, rarity: strings.rarity_name(view.rarity), season: view.season_number)
  end

  # A card's face, leading to its detail in its own season, or in season
  # `number` when given, named by card_detail_open_label, as not owned when
  # `owned` is false. The `context` it carries (card_detail_path) is what
  # the detail walks with ◀ ▶ and leads back to.
  def link_to_card_detail(view, strings:, context: {}, number: view.season_number, owned: true, &)
    link_to(card_detail_path(view.id, number, context), class: "card-link", aria: { label: card_detail_open_label(view, strings, owned:) },
      data: { turbo_prefetch: false }, &)
  end

  # The detail of the card `slug` of season `number`, carrying its browse
  # context in the query: `grid:` (the collection grid's filters and
  # search), `pack:` and `slot:` (an opened pack's token and the card's
  # place in it), `set_kind:` and `set_key:` (a set, with `brother:` a
  # player's album of it), or `brother:` alone (that player's profile
  # showcase); none for the card's own page.
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

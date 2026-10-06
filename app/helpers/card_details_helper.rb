# The words and links of a card's detail and of the links leading to it
# (CAP-7, story 4.3; epic 10 R2: a set to browse, ◀ and ▶), its faded card
# back (AD-25), and its link previews (CAP-9).
module CardDetailsHelper
  # Open Graph's name of each locale of the URL.
  OG_LOCALES = { "en" => "en_US", "fr" => "fr_FR" }.freeze

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

  # The page's locale as Open Graph names it: "en_US", "fr_FR".
  def og_locale
    OG_LOCALES.fetch(I18n.locale.to_s)
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

  # The name of a link to a card's detail: "Portal, Epic, season 1".
  def card_detail_open_label(view, strings)
    t("card_details.open", title: view.title, rarity: strings.rarity_name(view.rarity), season: view.season_number)
  end

  # A card's face or empty slot, leading to its detail in its own season. A
  # face, given its `strings`, is named by card_detail_open_label; an empty
  # slot, without, by its visible text (title, year, "Missing card"), so a
  # screen reader tells it from an owned face. Given the `set` (kind and
  # key) of the grid it sits in, the detail browses that set and shows a
  # card the viewer does not hold as their faded card back.
  def link_to_card_detail(view, strings: nil, set: nil, &)
    aria = strings ? { label: card_detail_open_label(view, strings) } : {}
    link_to(card_detail_path(view.id, view.season_number, set), class: "card-link", aria:,
      data: { turbo_prefetch: false }, &)
  end

  # The detail of the card `slug` of season `number`, browsing `set` (kind
  # and key) when given: a card's own path, a grid's link, ◀ and ▶.
  def card_detail_path(slug, number, set = nil)
    query = set ? { set_kind: set.kind, set_key: set.key } : {}
    card_season_path(slug:, number:, **query)
  end

  # The detail of the card before or after `view` in the set it browses
  # (a Catalog::SetNeighbours), in the same season; nil at an end.
  def card_detail_neighbour_path(browse, view, side)
    slug = side == :previous ? browse.previous : browse.next
    slug && card_detail_path(slug, view.season_number, browse.set)
  end

  # The player's active card back (AD-25), at card-l size, decorative: the
  # exported pixel-art PNG of that size (AD-27, story 8.8), 104 × 156 art
  # pixels drawn at 2 CSS px each. An unknown key raises ArgumentError.
  def card_back_image(key, **options)
    raise ArgumentError, "unknown card back: #{key.inspect}" unless Game::CardBacks::KEYS.include?(key.to_s)

    image_tag(vite_asset_path("images/pixel/back-#{key}-l.png"), alt: "", width: 208, height: 312, **options)
  end
end

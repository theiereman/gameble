module LandingsHelper
  THUMB_ART = { small: 18, large: 32 }.freeze

  LAMP_SLOTS = [
    { rarity: :rare, size: :l },
    { rarity: :common, size: :m },
    { rarity: :epic, size: :m },
    { rarity: :uncommon, size: :s },
    { rarity: nil, size: :s },
    { rarity: :legendary, size: :s }
  ].freeze

  GAUGE_SEGMENTS = 24
  RESERVE_CELLS = 10

  def landing_module_heading(key, id:, modifier: nil)
    tag.h2(id:, tabindex: -1, class: class_names("landing-module__heading", "landing-module__heading--#{modifier}" => modifier)) do
      safe_join([
        tag.span(t("landings.show.#{key}.label"), class: "landing-module__label"),
        tag.span(", ", class: "visually-hidden"),
        tag.span(t("landings.show.#{key}.title"), class: "landing-module__title")
      ])
    end
  end

  def landing_lamp_slots(samples)
    LAMP_SLOTS.map { |slot| slot.merge(view: slot[:rarity] && samples[slot[:rarity]]) }
  end

  def landing_covers(samples)
    samples.values.compact
  end

  def landing_thumb(covers, index, size: :small)
    cover = covers[index % covers.size] if covers.any?
    return tag.span(class: [ "landing-thumb", "landing-thumb--#{size}", "landing-thumb--empty" ]) if cover.nil?

    art = THUMB_ART.fetch(size)
    tag.span(class: [ "landing-thumb", "landing-thumb--#{size}", "landing-thumb--#{cover.rarity}" ],
      data: { controller: "card-art", card_art_url_value: cover.image_url, card_art_width_value: art, card_art_height_value: art,
              card_art_palette_width_value: CardComponent::PALETTE[:width], card_art_palette_height_value: CardComponent::PALETTE[:height] }) do
      tag.canvas(class: "landing-thumb__canvas", width: art, height: art, data: { card_art_target: "canvas" })
    end
  end

  def landing_card_back(size, **options)
    width, height = size == :m ? [ 160, 240 ] : [ 112, 168 ]
    image_tag(vite_asset_path("images/pixel/back-#{Game::CardBacks::STANDARD}-#{size}.png"), alt: "", width:, height:,
      class: [ "landing-card-back", options.delete(:class) ], **options)
  end

  def landing_reveal_announcement(view)
    details = [ view.publisher.presence, view.year, (SetLabel.genre(view.genre) if view.genre) ].compact.join(", ")
    t("landings.show.how.discover.announcement", title: view.title, details:, rarity: t("catalog.rarity.#{view.rarity}"))
  end

  def landing_gauge(lit, **options)
    tag.span(class: [ "landing-gauge", options[:class] ], aria: { hidden: true }) do
      safe_join(Array.new(GAUGE_SEGMENTS) { |index| tag.span(class: class_names("landing-gauge__segment", "is-lit" => index < lit)) })
    end
  end

  def landing_pips(lit, **options)
    tag.span(class: [ "landing-pips", options[:class] ], aria: { hidden: true }) do
      safe_join(Array.new(RESERVE_CELLS) { |index| tag.span(class: class_names("landing-pips__cell", "is-lit" => index < lit)) })
    end
  end
end

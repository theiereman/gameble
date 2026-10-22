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

  MOVERS = [
    { rarity: :epic, size: :m, lane: :left, anchor: 0.06, speed: 1.7, sway: 36, offset: -0.3, rotation: -8 },
    { rarity: :legendary, size: :s, lane: :right, anchor: 0.22, speed: 1.9, sway: 28, offset: 0.2, rotation: 7 },
    { rarity: :uncommon, size: :s, lane: :left, anchor: 0.4, speed: 1.5, sway: 32, offset: 0.25, rotation: 10 },
    { rarity: :rare, size: :m, lane: :right, anchor: 0.58, speed: 1.8, sway: 40, offset: -0.15, rotation: -6 },
    { rarity: nil, size: :m, lane: :left, anchor: 0.78, speed: 1.6, sway: 30, offset: 0.1, rotation: 11 }
  ].freeze

  MODULE_KEYS = %i[concept brotherhood how live unlock roadmap open_source free boarding].freeze
  GAUGE_SEGMENTS = 24
  RESERVE_CELLS = 10

  def landing_feed_items
    LiveStream.landing_items
  rescue ActiveRecord::ActiveRecordError => error
    Rails.logger.error("landing feed unreadable: #{error.class}")
    []
  end

  def landing_module_heading(key, id:, modifier: nil)
    tag.h2(id:, tabindex: -1, class: class_names("landing-module__heading", "landing-module__heading--#{modifier}" => modifier)) do
      safe_join([
        tag.span(t("landings.show.#{key}.label"), class: "landing-module__label"),
        tag.span(", ", class: "visually-hidden"),
        tag.span(t("landings.show.#{key}.title"), class: "landing-module__title")
      ])
    end
  end

  def landing_gauge_markers
    markers = [ { number: "00", target: "landing-hero", label: t("landings.show.hero.marker"), name: t("landings.show.hero.marker").sub(/\A\d+ · /, "") } ]
    markers + MODULE_KEYS.each_with_index.map do |key, index|
      { number: format("%02d", index + 1), target: "landing-#{key.to_s.dasherize}", label: t("landings.show.#{key}.label"), name: t("landings.show.#{key}.label").sub(/\A\d+ · /, "") }
    end
  end

  def landing_lamp_slots(samples)
    LAMP_SLOTS.map { |slot| slot.merge(view: slot[:rarity] && samples[slot[:rarity]]) }
  end

  def landing_movers(samples)
    MOVERS.filter_map do |mover|
      view = mover[:rarity] && samples[mover[:rarity]]
      next if mover[:rarity] && view.nil?

      mover.merge(key: (mover[:rarity] || :back).to_s, view:)
    end
  end

  def landing_mover_data(mover)
    { key: mover[:key], size: mover[:size], lane: mover[:lane], anchor: mover[:anchor], speed: mover[:speed],
      sway: mover[:sway], offset: mover[:offset], rotation: mover[:rotation] }
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

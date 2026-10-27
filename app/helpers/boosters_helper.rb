module BoostersHelper
  RESERVE_PIPS = 10
  STATUSES = { sealed: "sealed", arming: "arming", ejecting: "ejecting", inventory: "inventory",
               legendarySignal: "legendary_signal", complete: "complete", waiting: "waiting" }.freeze
  BOOSTER_CHILDREN = %w[booster-info].freeze
  BOOSTER_ACTIONS = {
    "booster-actions" => { open: :open, reveal: :revealAll, back: :guardBack },
    "booster-canister" => { open: :open },
    "booster-stage" => { activate: :activateCard, repost: :repostCard, press: :pressCard, release: :releaseCard },
    "booster-plate" => { store: :storeTop },
    "booster-tray" => { zoom: :openZoom },
    "booster-zoom" => { step: :stepZoom, see: :seeZoomed, repost: :repostZoomed, close: :closeZoom },
    "booster-celebration" => { leave: :leaveForAlbum, step: :stepCelebration }
  }.freeze

  def booster_root_data(bank:, season:, next_pack_size:)
    values = booster_bank(bank:, next_pack_size:)
    {
      controller: "booster", action: screen_actions("booster", BOOSTER_ACTIONS),
      booster_open_url_value: packs_path, booster_card_url_value: card_path(slug: "SLUG"),
      booster_repost_url_value: season ? card_repost_path(slug: "SLUG", number: "NUMBER") : "",
      booster_bank_url_value: booster_path(format: :json), booster_delimiter_value: t("number.format.delimiter"),
      booster_pack_size_value: Game::Pack::SIZE, booster_season_value: season&.number || 0,
      booster_available_value: values[:available], booster_reserve_full_value: values[:reserveFull],
      booster_next_available_at_value: values[:nextAvailableAt] || "", booster_server_time_value: values[:serverTime],
      booster_next_pack_size_value: next_pack_size || 0, booster_strings_value: screen_strings("booster.strings")
    }.merge(screen_outlets("booster", BOOSTER_ACTIONS.keys + BOOSTER_CHILDREN))
  end

  def booster_bank(bank:, next_pack_size:)
    {
      available: bank[:available],
      reserveFull: bank[:reserve_full],
      nextAvailableAt: bank[:next_available_at] && opening_time(bank[:next_available_at]),
      serverTime: opening_time(Time.current),
      nextPackSize: next_pack_size
    }
  end

  def booster_state_words
    safe_join(STATUSES.map { |status, key| tag.span(t("booster.states.#{key}"), data: { status: }) })
  end

  def booster_pips(lit)
    safe_join(Array.new(RESERVE_PIPS) { |index| tag.span(class: "booster__pip", data: { lit: ("" if index < lit) }) })
  end

  def booster_reserve_count(available)
    t("booster.strings.reserve_count", count: available, n: number_with_delimiter(available))
  end

  def booster_canister_label(season, count)
    return t("booster.strings.canister_label_plain", count:) unless season

    t("booster.strings.canister_label", season: season.number, count:)
  end

  def booster_canister_facts(count)
    t("booster.strings.canister_facts", count:, n: number_with_delimiter(count))
  end

  def booster_rarities
    Catalog::Rarity::TIERS.map do |tier, code|
      name = t("catalog.rarity.#{code}")
      label = code == :legendary ? t("booster.legendary_banner", rarity: name) : name
      { code:, name:, label:, icon: pixel_icon("rarity-#{tier}", class: "booster-card__label-icon") }
    end
  end

  def booster_opened_card_data(card, index)
    { booster_target: "card", index: }.merge(pack_card_fields(card).transform_keys { it.to_s.underscore })
  end

  def booster_set_tier_data(row)
    { booster_target: "setTier", kind: row[:kind], key: row[:key], name: row[:name], tier: row[:tier], required: row[:required],
      held: row[:held], total: row[:total], url: row[:url], thresholds: row[:thresholds].map { "#{it[:tier]}:#{it[:required]}" }.join(" ") }
  end

  def booster_celebration_icon(name, extra = nil)
    tag.span(pixel_icon(name, class: "booster-celebration__icon"), class: class_names("booster-celebration__icon-wrap", extra), aria: { hidden: true })
  end

  def booster_rank_mark(rank)
    tag.span(rank_mark(rank, fine: false, class: "booster-celebration__icon"), class: "booster-celebration__icon-wrap booster-celebration__rank",
      aria: { hidden: true })
  end

  def booster_celebration_result(phone:)
    tag.a(class: "booster-celebration__banner", data: { turbo_prefetch: "false", action: "booster-celebration#leave" }) do
      safe_join([ booster_celebration_head(glints: true), booster_celebration_row, booster_celebration_gauge,
                  booster_celebration_icon("arrow-right", phone ? "booster-celebration__arrow" : "booster-celebration__hint booster-celebration__hint--arrow") ])
    end
  end

  def booster_celebration_folded(phone:)
    hint = if phone
      booster_celebration_icon("arrow-right", "booster-celebration__arrow")
    else
      tag.span(safe_join([ t("booster.strings.celebration.folded_hint"), booster_celebration_icon("arrow-small-right") ]),
        class: "booster-celebration__hint", aria: { hidden: true })
    end
    tag.a(href: library_path, class: "booster-celebration__banner", data: { tier: "folded", turbo_prefetch: "false", action: "booster-celebration#leave" }) do
      safe_join([ booster_celebration_head(glints: false), tag.span(class: "booster-celebration__marks", aria: { hidden: true }),
                  tag.span(tag.b(class: "booster-celebration__set"), class: "booster-celebration__sub", aria: { hidden: true }), hint ])
    end
  end

  def booster_celebration_step
    tag.div(class: "booster-celebration__step") do
      safe_join([ tag.span(class: "booster-celebration__position"),
                  tag.button(booster_celebration_icon("arrow-small-right"), type: "button", class: "button button--secondary booster-celebration__next",
                    aria: { label: t("booster.strings.celebration.next") }, data: { action: "booster-celebration#step" }) ])
    end
  end

  private
    def booster_celebration_head(glints:)
      ribbon = tag.span(tag.span(tag.span, class: "booster-celebration__ribbon"), class: "booster-celebration__wipe")
      glint = tag.span(safe_join([ tag.i, tag.i, tag.i ]), class: "booster-celebration__glints") if glints
      tag.span(safe_join([ ribbon, tag.i(class: "booster-celebration__fold"), glint ].compact), class: "booster-celebration__head", aria: { hidden: true })
    end

    def booster_celebration_row
      name = tag.span(safe_join([ tag.span(class: "booster-celebration__set-name"), tag.span(class: "booster-celebration__stamp") ]), class: "booster-celebration__name")
      roll = tag.span(tag.span(safe_join([ tag.span(class: "booster-celebration__before"), tag.span(class: "booster-celebration__owned") ])),
        class: "booster-celebration__roll")
      count = tag.span(safe_join([ roll, tag.span(class: "booster-celebration__total") ]), class: "booster-celebration__count")
      tag.span(safe_join([ name, count ]), class: "booster-celebration__row", aria: { hidden: true })
    end

    def booster_celebration_gauge
      parts = [ tag.i(class: "booster-celebration__fill booster-celebration__fill--new"), tag.i(class: "booster-celebration__fill booster-celebration__fill--before"),
                tag.i(class: "booster-celebration__lime"), tag.i(class: "booster-celebration__glow"), tag.span(class: "booster-celebration__end") ]
      tag.span(safe_join(parts), class: "booster-celebration__gauge", aria: { hidden: true })
    end
end

module CardBacksHelper
  SetRef = Data.define(:kind, :params)

  PHONE_MEDIA = "(max-width: 719px)".freeze

  def card_back_name(back)
    return set_label(back) if back.unlock.kind == :set_tier

    t("card_backs.names.#{back.key}")
  end

  def card_back_condition(back)
    return t("card_backs.conditions.set_tier", set: set_label(back)) if back.unlock.kind == :set_tier

    t("card_backs.conditions.#{back.unlock.kind}")
  end

  def card_back_image(back, size)
    image_tag vite_asset_path("images/pixel/#{back.asset}-#{size}.png"), alt: "", class: "back-picker__image"
  end

  def card_back_picture(back)
    tag.picture(class: "back-picker__picture") do
      safe_join([
        tag.source(media: PHONE_MEDIA, srcset: vite_asset_path("images/pixel/#{back.asset}-s.png"), width: 56, height: 84),
        image_tag(vite_asset_path("images/pixel/#{back.asset}-m.png"), alt: "", width: 80, height: 120, class: "back-picker__image")
      ])
    end
  end

  def card_back_sentence(row)
    row.locked? ? card_back_to_earn(row) : card_back_earned(row)
  end

  def card_back_tail(row)
    row.locked? ? card_back_progress(row.progress) : card_back_earned_on(row)
  end

  def card_back_spoken_tail(row)
    row.locked? ? card_back_progress(row.progress, spoken: true) : card_back_earned_on(row)
  end

  def card_back_label(row, state: row.state)
    parts = { name: card_back_name(row.back), state: card_back_state(state), sentence: card_back_sentence(row) }
    tail = card_back_spoken_tail(row)
    label = tail ? t("personalizations.show.card_back.label_with_tail", **parts, tail:) : t("personalizations.show.card_back.label", **parts)
    state == :unlocked ? t("personalizations.show.card_back.label_to_equip", label:) : label
  end

  def card_back_season_label(back, season)
    t("personalizations.show.card_back.season_label", name: card_back_name(back), season:)
  end

  def card_back_equipped(back, season)
    name = card_back_name(back)
    season ? t("personalizations.show.card_back.equipped_with_season", name:, season:) : t("personalizations.show.card_back.equipped", name:)
  end

  private
    def set_label(back)
      kind, key = back.unlock.target
      SetLabel.for(SetRef.new(kind:, params: { kind => key }))
    end

    def card_back_state(state)
      case state
      when :active then t("personalizations.show.card_back.states.active")
      when :unlocked then t("personalizations.show.card_back.states.unlocked")
      else t("personalizations.show.card_back.states.locked")
      end
    end

    def card_back_earned(row)
      case row.unlock.kind
      when :always then t("personalizations.show.card_back.earned.always")
      when :event then t("personalizations.show.card_back.earned.events.#{row.key}")
      when :achievement then t("personalizations.show.card_back.earned.achievement", **achievement_parts(row))
      when :goal then earned_by_goal(row)
      when :set_tier then earned_by_set(row)
      end
    end

    def card_back_to_earn(row)
      case row.unlock.kind
      when :achievement then t("personalizations.show.card_back.to_earn.achievement", **achievement_parts(row))
      when :goal then t("personalizations.show.card_back.to_earn.goal")
      when :set_tier
        row.progress ? t("personalizations.show.card_back.to_earn.set", set: set_label(row.back)) : t("personalizations.show.card_back.to_earn.set_absent")
      else t("personalizations.show.card_back.to_earn.event")
      end
    end

    def earned_by_goal(row)
      return t("personalizations.show.card_back.earned.goal_any") unless row.week

      t("personalizations.show.card_back.earned.goal", week: l(row.week, format: row.week.day == 1 ? :day_month_first : :day_month))
    end

    def earned_by_set(row)
      set = set_label(row.back)
      return t("personalizations.show.card_back.earned.set_any", set:) unless row.tier

      t("personalizations.show.card_back.earned.set", tier: t("library.set_progress.tiers.#{row.tier}"), set:, seasons: card_back_seasons(row.seasons))
    end

    def card_back_seasons(seasons)
      connector = t("personalizations.show.card_back.seasons_connector")
      list = seasons.to_sentence(two_words_connector: connector, last_word_connector: connector)
      t("personalizations.show.card_back.seasons", count: seasons.size, list:)
    end

    def achievement_parts(row)
      achievement = row.unlock.target
      { name: t("achievements.names.#{achievement}"), condition: t("achievements.conditions.#{achievement}") }
    end

    def card_back_earned_on(row)
      return t("personalizations.show.card_back.on_sign_up") if row.unlock.kind == :always
      return unless row.unlocked_at

      day = row.unlocked_at.to_date
      t("personalizations.show.card_back.on_date", date: l(day, format: day.day == 1 ? :long_day_first : :long_day))
    end

    def card_back_progress(progress, spoken: false)
      return unless progress

      figures = { held: progress.held, total: progress.total, missing: progress.missing }
      if progress.missing.positive?
        spoken ? t("personalizations.show.card_back.progress.spoken_missing", count: progress.held, **figures) : t("personalizations.show.card_back.progress.shown_missing", **figures)
      else
        spoken ? t("personalizations.show.card_back.progress.spoken", count: progress.held, **figures) : t("personalizations.show.card_back.progress.shown", **figures)
      end
    end
end

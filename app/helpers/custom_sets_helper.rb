module CustomSetsHelper
  SHOWN_ON_PHONE = 2

  def custom_set_display_name(custom_set)
    custom_set.custom? ? custom_set.name : t("custom_sets.library.name")
  end

  def steam_library_kind_line(library)
    t("library.entry.steam_library.kind", count: library.total, games: number_with_delimiter(library.total))
  end

  def custom_set_kind_line(custom_set)
    t("library.entry.custom_sets.kind", count: custom_set.total, games: number_with_delimiter(custom_set.total))
  end

  def own_set_kind_line(own_set)
    own_set.custom? ? custom_set_kind_line(own_set) : steam_library_kind_line(own_set)
  end

  def own_set_tile_name(own_set, goal: nil)
    return steam_library_tile_name(own_set) if own_set.steam_library?

    [ own_set.name, t("library.entry.goals.custom_kind").downcase, (t("goals.tile_words", number: goal.position) if goal),
      set_album_value_text(own_set.to_set_standing) ].compact.join(", ")
  end

  def steam_library_tile_name(library)
    [ custom_set_display_name(library), set_album_value_text(library.to_set_standing) ].join(", ")
  end

  def steam_library_sync_lines(library)
    return [ t("library.entry.steam_library.synced", date: steam_library_date(library.synced_at)) ] unless library.library_private?

    [ t("library.entry.steam_library.not_shared"),
      (t("library.entry.steam_library.last_sync", date: steam_library_date(library.synced_at)) if library.synced_at) ].compact
  end

  private

  def steam_library_date(time)
    day = time.to_date
    l(day, format: day.day == 1 ? :long_day_first : :long_day)
  end
end

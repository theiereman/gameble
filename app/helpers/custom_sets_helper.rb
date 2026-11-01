module CustomSetsHelper
  def custom_set_display_name(custom_set)
    custom_set.custom? ? custom_set.name : t("custom_sets.library.name")
  end

  def steam_library_kind_line(library)
    t("library.entry.steam_library.kind", count: library.total, games: number_with_delimiter(library.total))
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

module DuelProfileHelper
  def duel_stat_words(stat, rarity:)
    high = stat.percentile >= 50
    percent = number_to_percentage((high ? stat.percentile : 100 - stat.percentile).round.clamp(0, 99), precision: 0)
    t("duel_stats.words.#{stat.name}.#{high ? "high" : "low"}", percent:, rarity: t("duel_stats.rarities.#{rarity}"))
  end

  def duel_stat_value(stat)
    case stat.name
    when :popularity, :circulation
      t("duel_stats.values.#{stat.name}", count: stat.value, number: number_with_delimiter(stat.value))
    when :rating then t("duel_stats.values.rating", percent: number_to_percentage(stat.value, precision: 0))
    when :release then duel_profile_date(stat.value)
    when :discovery then duel_profile_date(stat.value.in_time_zone.to_date)
    end
  end

  def duel_stat_bar_value(stat) = stat.percentile.to_s("F")

  def duel_profile_dated(profile)
    t("duel_stats.dated", date: duel_profile_date(profile.computed_at.in_time_zone.to_date))
  end

  private
    def duel_profile_date(day)
      l(day, format: day.day == 1 ? :long_day_first : :long_day)
    end
end

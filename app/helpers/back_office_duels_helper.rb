module BackOfficeDuelsHelper
  def duel_share(count, total)
    return t("back_office.duels.no_value") if total.zero?

    number_to_percentage(count * 100.0 / total, precision: 0)
  end
end

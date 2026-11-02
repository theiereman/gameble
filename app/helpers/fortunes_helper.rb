module FortunesHelper
  def fortune_index_text(index)
    index.positive? ? "+#{index}" : index.to_s
  end

  def fortune_label_title(index) = t("fortunes.labels.#{Game::FortuneIndex.label(index)}.title")

  def fortune_label_text(index) = t("fortunes.labels.#{Game::FortuneIndex.label(index)}.text")

  def fortune_index_tone(index)
    if index.positive? then "fortune-index--up"
    elsif index.negative? then "fortune-index--down"
    end
  end
end

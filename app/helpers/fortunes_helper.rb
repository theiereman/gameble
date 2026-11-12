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

  def fortune_share_tag(standing, class_name:)
    tag.span(class: class_name) do
      safe_join([ tag.span(t("fortunes.share.#{standing.top_half? ? "top" : "bottom"}"), class: "#{class_name}-word"),
        tag.span(t("fortunes.share.percent", percent: standing.share_of_half), class: "#{class_name}-value") ], " ")
    end
  end

  def fortune_gauge_text(distribution, standing)
    return t("fortunes.gauge.empty") if distribution.total.zero?

    crowd = t("fortunes.gauge.crowd", count: distribution.total, index: fortune_index_text(distribution.crowded_index))
    return crowd unless standing&.rank

    "#{crowd} #{t("fortunes.gauge.marked", index: fortune_index_text(standing.index), rank: standing.rank, total: standing.ranked_count)}"
  end

  def player_card_dialog_id(token) = "player-card-#{token}"

  def player_card_frame_id(token) = "player-card-frame-#{token}"
end

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

  def fortune_period_param(period) = (period.to_s unless period == :week)

  def player_card_dialog_id(token) = "player-card-#{token}"

  def player_card_frame_id(token) = "player-card-frame-#{token}"
end

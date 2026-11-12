module HubMarketHelper
  def hub_volume_drawing(volume) = Charts::Drawing.new(kind: "volume", labels: chart_labels(volume.days), series: { volume: volume.amounts })

  def hub_volume_change(volume)
    percent = volume.change_percent
    return if percent.nil?

    trend = hub_volume_trend(percent)
    tag.span(class: "hub-volume__change hub-volume__change--#{trend}") do
      safe_join([ tag.span(t("pages.home.market.volume.#{trend}", percent: percent.abs), aria: { hidden: true }),
        tag.span(t("pages.home.market.volume.spoken_#{trend}", percent: percent.abs), class: "visually-hidden") ])
    end
  end

  private
    def hub_volume_trend(percent)
      return :flat if percent.zero?

      percent.positive? ? :up : :down
    end
end

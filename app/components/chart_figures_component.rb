class ChartFiguresComponent < ViewComponent::Base
  def initialize(figures:)
    @figures = figures
  end

  def call
    tag.dl(class: "chart-figures") do
      safe_join(@figures.map do |label, value|
        tag.div(class: "chart-figures__item") { tag.dt(label, class: "chart-figures__label") + tag.dd(value, class: "chart-figures__value") }
      end)
    end
  end
end

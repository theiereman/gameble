require "test_helper"

class ChartComponentTest < ViewComponent::TestCase
  def drawing(**overrides)
    Charts::Drawing.new(
      kind: "reactor", title: "MINTED AND DESTROYED PER DAY", summary: "Over 30 days, 12 PiCoins minted.",
      labels: [ "Nov 8", "Nov 9" ], series: { minted: [ 5, nil ], destroyed: [ 2, nil ], balance: [ 3, nil ] },
      words: { tooltip: "%{series}: %{value}" }, legend: [ [ :minted, "Minted" ], [ :destroyed, "Destroyed" ] ],
      table: Charts::Table.new(caption: "Per day", columns: %w[Day Minted],
        rows: [ Charts::Row.new(day: Date.new(2026, 11, 8), cells: [ "5" ]), Charts::Row.new(day: Date.new(2026, 11, 9), cells: [ "—" ]) ]),
      **overrides
    )
  end

  test "a chart is a figure titled by its caption, its canvas an image named by the title and described by the summary" do
    render_inline ChartComponent.new(drawing: drawing, id: "reactor-flows")

    assert_selector "figure#reactor-flows.chart.chart--regular[aria-labelledby=reactor-flows-title]"
    assert_selector "figure figcaption h3#reactor-flows-title", text: "MINTED AND DESTROYED PER DAY"
    assert_selector "canvas[role=img][aria-labelledby=reactor-flows-title][aria-describedby=reactor-flows-summary]"
    assert_selector "p#reactor-flows-summary", text: "Over 30 days, 12 PiCoins minted."
    assert_selector ".chart__legend li", count: 2
    assert_selector ".chart__swatch--minted[aria-hidden=true]"
    assert_no_selector "[style]"
  end

  test "the series value holds the kind, the labels and the series by meaning, with nulls kept and no colour, id or token" do
    render_inline ChartComponent.new(drawing: drawing, id: "reactor-flows")

    figure = page.find("figure")
    series = JSON.parse(figure["data-chart-series-value"])

    assert_equal "chart", figure["data-controller"]
    assert_equal %w[kind labels series], series.keys
    assert_equal %w[minted destroyed balance], series["series"].keys
    assert_equal [ 5, nil ], series["series"]["minted"]
    assert_no_match(/#[0-9a-f]{3,6}|color|colour|token|"id"/i, figure["data-chart-series-value"])
    assert_equal({ "tooltip" => "%{series}: %{value}" }, JSON.parse(figure["data-chart-words-value"]))
  end

  test "its table lists every day drawn, newest first, the day a time in a row header" do
    render_inline ChartComponent.new(drawing: drawing, id: "reactor-flows")

    assert_selector "details summary", text: "SHOW THE TABLE"
    assert_selector "table caption", text: "Per day", visible: :all
    assert_selector "thead th[scope=col]", count: 2, visible: :all
    rows = page.all("tbody tr", visible: :all)
    assert_equal 2, rows.size
    assert_equal "2026-11-09", rows.first.find("th[scope=row] time", visible: :all)["datetime"]
    assert_equal "2026-11-08", rows.last.find("th[scope=row] time", visible: :all)["datetime"]
  end

  test "a chart shown to staff while unpublished is flagged inside its title, and only then" do
    render_inline ChartComponent.new(drawing: drawing, id: "reactor-flows", staff_only: true)

    assert_selector "figcaption h3#reactor-flows-title .chart__staff-flag", text: "VISIBLE TO STAFF"

    render_inline ChartComponent.new(drawing: drawing, id: "reactor-flows")

    assert_no_selector ".chart__staff-flag"
  end

  test "a short chart draws at the short height and refuses an unknown size" do
    render_inline ChartComponent.new(drawing: drawing(legend: []), id: "reactor-circulation", size: :short)

    assert_selector "figure.chart--short"
    assert_no_selector ".chart__legend"
    assert_raises(ArgumentError) { ChartComponent.new(drawing: drawing, id: "x", size: :huge) }
  end
end

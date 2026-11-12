module ReactorChartsHelper
  def reactor_figures(reactor)
    [
      [ t("charts.reactor.figures.circulation"), chart_compact_picoins(reactor.last_circulation) ],
      [ t("charts.reactor.figures.minted"), chart_compact_picoins(reactor.minted_total) ],
      [ t("charts.reactor.figures.destroyed"), chart_compact_picoins(reactor.destroyed_total) ],
      [ t("charts.reactor.figures.ratio"), chart_share(reactor.destroyed_share_basis_points) ]
    ]
  end

  def reactor_flows_drawing(reactor)
    Charts::Drawing.new(
      kind: "reactor", title: t("charts.reactor.flows.title"), summary: reactor_flows_summary(reactor),
      labels: chart_labels(reactor.days), series: { minted: reactor.minted, destroyed: reactor.destroyed, balance: reactor.balance },
      words: t("charts.reactor.words"), legend: %i[minted destroyed].map { [ it, t("charts.reactor.words.series.#{it}") ] },
      table: Charts::Table.new(
        caption: t("charts.reactor.flows.caption"),
        columns: %i[day minted destroyed balance].map { t("charts.reactor.columns.#{it}") },
        rows: reactor.days.each_index.map do |index|
          Charts::Row.new(day: reactor.days[index], cells: [ chart_picoins(reactor.minted[index]), chart_picoins(reactor.destroyed[index]),
            chart_signed_picoins(reactor.balance[index]) ])
        end
      )
    )
  end

  def reactor_circulation_drawing(reactor)
    Charts::Drawing.new(
      kind: "circulation", title: t("charts.reactor.circulation.title"), summary: reactor_circulation_summary(reactor),
      labels: chart_labels(reactor.days), series: { circulation: reactor.circulation }, words: t("charts.circulation.words"),
      table: Charts::Table.new(
        caption: t("charts.reactor.circulation.caption"),
        columns: %i[day circulation].map { t("charts.reactor.columns.#{it}") },
        rows: reactor.days.zip(reactor.circulation).map { |day, circulation| Charts::Row.new(day:, cells: [ chart_picoins(circulation) ]) }
      )
    )
  end

  def chart_labels(days) = days.map { chart_day(it) }

  private
    def reactor_flows_summary(reactor)
      return t("charts.reactor.empty") if reactor.empty?

      t("charts.reactor.flows.summary", minted: picoins(reactor.minted_total), destroyed: picoins(reactor.destroyed_total),
        ratio: chart_share_words(reactor.destroyed_share_basis_points), circulation: picoins(reactor.last_circulation))
    end

    def reactor_circulation_summary(reactor)
      return t("charts.reactor.empty") if reactor.empty?

      known = reactor.days.zip(reactor.circulation).reject { |_, circulation| circulation.nil? }
      (first_day, first), (last_day, last) = known.first, known.last
      t("charts.reactor.circulation.summary", first: picoins(first), first_day: chart_day(first_day), last: picoins(last), last_day: chart_day(last_day))
    end
end

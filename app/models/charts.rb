module Charts
  Drawing = Data.define(:kind, :title, :summary, :labels, :series, :words, :table, :legend) do
    def initialize(kind:, labels:, series:, title: nil, summary: nil, words: {}, table: nil, legend: [])
      super
    end

    def to_series_json = { kind:, labels:, series: }.to_json
  end

  Table = Data.define(:caption, :columns, :rows)

  Row = Data.define(:day, :cells)
end

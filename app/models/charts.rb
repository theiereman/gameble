module Charts
  Drawing = Data.define(:kind, :title, :summary, :labels, :series, :words, :table, :legend, :x) do
    def initialize(kind:, labels:, series:, title: nil, summary: nil, words: {}, table: nil, legend: [], x: nil)
      super
    end

    def to_series_json = { kind:, labels:, series:, x: }.compact.to_json
  end

  Table = Data.define(:caption, :columns, :rows)

  Row = Data.define(:day, :cells)
end

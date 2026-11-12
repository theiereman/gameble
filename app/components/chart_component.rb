class ChartComponent < ViewComponent::Base
  SIZES = %i[regular short index].freeze

  def initialize(drawing:, id:, size: :regular, heading: :h3, staff_only: false)
    raise ArgumentError, "unknown chart size: #{size.inspect}" unless SIZES.include?(size)

    @drawing = drawing
    @id = id
    @size = size
    @heading = heading
    @staff_only = staff_only
  end

  private
    attr_reader :drawing, :id, :heading, :staff_only

    def title_id = "#{id}-title"

    def summary_id = "#{id}-summary"

    def table_id = "#{id}-table"

    def classes = [ "chart", "chart--#{@size}" ].join(" ")

    def controller_data
      { controller: "chart", chart_series_value: drawing.to_series_json, chart_words_value: drawing.words.to_json }
    end

    def rows_newest_first = drawing.table.rows.reverse
end

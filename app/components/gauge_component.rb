class GaugeComponent < ViewComponent::Base
  SEGMENTS = 24

  def self.lit(value, max, segments: SEGMENTS)
    return 0 unless max.positive?

    (value.clamp(0, max) * segments) / max
  end

  def initialize(lit:, segments: SEGMENTS, segment_data: {}, **html_options)
    @lit = lit
    @segments = segments
    @segment_data = segment_data
    @html_options = html_options
  end

  private
    def classes
      [ "gauge", @html_options[:class] ].compact.join(" ")
    end

    def segment_classes(index)
      [ "gauge__segment", ("gauge__segment--lit" if index < @lit) ].compact.join(" ")
    end
end

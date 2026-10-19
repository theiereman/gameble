module LocalTimeHelper
  STYLES = %i[datetime date_time_year time weekday_time].freeze
  TIME_ZONE_COOKIE = "time_zone"

  def local_time_tag(time, style = :datetime, suffix: nil, **attributes)
    raise ArgumentError, "unknown local time style: #{style.inspect}" unless STYLES.include?(style)

    data = { controller: "local-time", local_time_style_value: style.to_s.dasherize, local_time_suffix_value: suffix }
    data = data.compact.merge(attributes.delete(:data) || {})
    tag.time(time && local_time_shown(time, style, suffix), datetime: time&.utc&.iso8601, data:, **attributes)
  end

  def local_time_text(time, style = :datetime)
    zone = reader_time_zone
    return time.utc.strftime(style == :time ? "%H:%M UTC" : "%Y-%m-%d %H:%M UTC") unless zone

    I18n.l(time.in_time_zone(zone), format: :"local_#{style}")
  end

  def local_time_sentence(time, style = :datetime, suffix: nil)
    text = local_time_text(time, style)
    sentence = yield text
    before, after = sentence.split(text, 2)
    after.nil? ? sentence : safe_join([ before, local_time_tag(time, style, suffix:), after ])
  end

  private

  def local_time_shown(time, style, suffix)
    reader_time_zone ? "#{local_time_text(time, style)}#{suffix}" : local_time_text(time, style)
  end

  def reader_time_zone
    return @reader_time_zone if defined?(@reader_time_zone)

    name = request&.cookies&.[](TIME_ZONE_COOKIE)
    @reader_time_zone = (ActiveSupport::TimeZone[name] if name.present?)
  end
end

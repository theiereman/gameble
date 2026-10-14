module LocalTimeHelper
  STYLES = %i[datetime date_time_year time weekday_time].freeze

  def local_time_tag(time, style = :datetime, suffix: nil, **attributes)
    raise ArgumentError, "unknown local time style: #{style.inspect}" unless STYLES.include?(style)

    data = { controller: "local-time", local_time_style_value: style.to_s.dasherize, local_time_suffix_value: suffix }
    data = data.compact.merge(attributes.delete(:data) || {})
    tag.time(time && local_time_fallback(time, style), datetime: time&.utc&.iso8601, data:, **attributes)
  end

  def local_time_fallback(time, style = :datetime)
    time.utc.strftime(style == :time ? "%H:%M UTC" : "%Y-%m-%d %H:%M UTC")
  end

  def local_time_sentence(time, style = :datetime, suffix: nil)
    fallback = local_time_fallback(time, style)
    sentence = yield fallback
    before, after = sentence.split(fallback, 2)
    after.nil? ? sentence : safe_join([ before, local_time_tag(time, style, suffix:), after ])
  end
end

require "test_helper"

# An instant the browser shows in its own time zone, with a UTC text that
# reads without JavaScript.
class LocalTimeHelperTest < ActionView::TestCase
  NEXT_DAY = Time.utc(2026, 10, 15)

  test "the tag carries the instant in UTC ISO 8601, the controller and the style" do
    render inline: local_time_tag(NEXT_DAY.in_time_zone("Europe/Paris"), :weekday_time, class: "feed__time")

    assert_select "time.feed__time[datetime='2026-10-15T00:00:00Z'][data-controller='local-time'][data-local-time-style-value='weekday-time']",
      "2026-10-15 00:00 UTC"
  end

  test "the fallback writes the date and the time in UTC, or the time alone" do
    assert_equal "2026-10-14 23:30 UTC", local_time_fallback(Time.utc(2026, 10, 14, 23, 30).in_time_zone("Europe/Paris"))
    assert_equal "00:00 UTC", local_time_fallback(NEXT_DAY, :time)
  end

  test "the style defaults to a date and time" do
    render inline: local_time_tag(NEXT_DAY)

    assert_select "time[data-local-time-style-value='datetime']", "2026-10-15 00:00 UTC"
  end

  test "data attributes join the controller's" do
    render inline: local_time_tag(NEXT_DAY, :date_time_year, data: { data_export_target: "time" })

    assert_select "time[data-controller='local-time'][data-data-export-target='time'][data-local-time-style-value='date-time-year']"
  end

  test "without an instant the tag is empty, for a script to fill" do
    render inline: local_time_tag(nil, :date_time_year)

    assert_select "time:not([datetime])", ""
  end

  test "a suffix goes to the controller, never into the UTC text" do
    render inline: local_time_sentence(NEXT_DAY, :time, suffix: ", local time") { "The day changes at #{it}." }

    assert_select "time[data-local-time-suffix-value=', local time']", "00:00 UTC"
    assert_equal "The day changes at 00:00 UTC.", Nokogiri::HTML5.fragment(rendered).text
  end

  test "without a suffix the tag carries none" do
    render inline: local_time_tag(NEXT_DAY)

    assert_select "time[data-local-time-suffix-value]", false
  end

  test "an unknown style is refused" do
    assert_raises(ArgumentError) { local_time_tag(NEXT_DAY, :relative) }
  end

  test "a sentence holds the time as the tag, and the rest of it escaped" do
    render inline: local_time_sentence(NEXT_DAY) { "<b>Next</b>: #{it}." }

    assert_includes rendered, "&lt;b&gt;Next&lt;/b&gt;: <time"
    assert_select "time[datetime='2026-10-15T00:00:00Z']", "2026-10-15 00:00 UTC"
    assert rendered.end_with?("</time>.")
  end

  test "a sentence without the time stays as written" do
    assert_equal "Your reserve is full.", local_time_sentence(NEXT_DAY) { "Your reserve is full." }
  end
end

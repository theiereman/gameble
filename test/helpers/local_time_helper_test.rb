require "test_helper"

# An instant the browser shows in its own time zone, with a UTC text that
# reads without JavaScript, or the browser's own text once its zone is known.
class LocalTimeHelperTest < ActionView::TestCase
  NEXT_DAY = Time.utc(2026, 10, 15)
  NEXT_WEEK = Time.utc(2026, 10, 19)

  def browser_zone(zone) = request.set_header("HTTP_COOKIE", "time_zone=#{CGI.escape(zone)}")

  test "the tag carries the instant in UTC ISO 8601, the controller and the style" do
    render inline: local_time_tag(NEXT_DAY.in_time_zone("Europe/Paris"), :weekday_time, class: "feed__time")

    assert_select "time.feed__time[datetime='2026-10-15T00:00:00Z'][data-controller='local-time'][data-local-time-style-value='weekday-time']",
      "2026-10-15 00:00 UTC"
  end

  test "without the browser's zone the text writes the date and the time in UTC, or the time alone" do
    assert_equal "2026-10-14 23:30 UTC", local_time_text(Time.utc(2026, 10, 14, 23, 30).in_time_zone("Europe/Paris"))
    assert_equal "00:00 UTC", local_time_text(NEXT_DAY, :time)
  end

  test "with the browser's zone the text is the one local_time.ts writes, in French" do
    browser_zone("Europe/Paris")

    I18n.with_locale(:fr) do
      assert_equal "15 oct. à 01h30", local_time_text(Time.utc(2026, 10, 14, 23, 30))
      assert_equal "4 oct. 2026 à 09h05", local_time_text(Time.utc(2026, 10, 4, 7, 5), :date_time_year)
      assert_equal "02h00", local_time_text(NEXT_DAY, :time)
      assert_equal "lundi à 02h00", local_time_text(NEXT_WEEK, :weekday_time)
    end
  end

  test "with the browser's zone the text is the one local_time.ts writes, in English" do
    browser_zone("Europe/Paris")

    assert_equal "Oct 15, 02:00", local_time_text(NEXT_DAY)
    assert_equal "Oct 4, 2026, 09:05", local_time_text(Time.utc(2026, 10, 4, 7, 5), :date_time_year)
    assert_equal "02:00", local_time_text(NEXT_DAY, :time)
    assert_equal "Monday 02:00", local_time_text(NEXT_WEEK, :weekday_time)
  end

  test "the text follows the browser's zone" do
    browser_zone("America/New_York")

    I18n.with_locale(:fr) { assert_equal "dimanche à 20h00", local_time_text(NEXT_WEEK, :weekday_time) }
  end

  test "a zone no one knows keeps the UTC text" do
    browser_zone("Mars/Olympus")

    assert_equal "2026-10-15 00:00 UTC", local_time_text(NEXT_DAY)
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

  test "with the browser's zone the tag holds its text and the suffix, as the controller writes them" do
    browser_zone("Europe/Paris")

    render inline: local_time_sentence(NEXT_DAY, :time, suffix: ", local time") { "The day changes at #{it}." }

    assert_select "time[data-local-time-suffix-value=', local time']", "02:00, local time"
    assert_equal "The day changes at 02:00, local time.", Nokogiri::HTML5.fragment(rendered).text
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

require "test_helper"

class LiveGoalJobTest < ActiveSupport::TestCase
  include ActionCable::TestHelper

  def received(locale)
    Nokogiri::HTML5.fragment(ActiveSupport::JSON.decode(broadcasts(LiveStream.goal_streamables(locale).join(":")).sole))
  end

  def panel(locale)
    stream = received(locale).css("turbo-stream[action=replace][target=community-goal]").sole
    Nokogiri::HTML5.fragment(stream.at_css("template").inner_html)
  end

  test "every hub's goal panel is replaced with the figures last summed, once per locale" do
    Game::WeeklyGoal.create!(week_start: Game::WeeklyGoal.week_start(Time.current), total: 1_250, target: 5_000)

    LiveGoalJob.perform_now

    english = panel(:en)
    assert_equal "1,250 / 5,000", english.at_css("#community-goal .hub-goal__figures").text
    assert_equal 6, english.css(".hub-goal__segment--lit").size
    assert_empty english.css("[style]")
    assert_match(/\A1[\s  ]250 \/ 5[\s  ]000\z/, panel(:fr).at_css(".hub-goal__figures").text)
    assert_equal "Objectif communautaire", panel(:fr).at_css(".hub-goal__title").text
  end
end

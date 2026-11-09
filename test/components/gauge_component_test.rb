require "test_helper"

class GaugeComponentTest < ViewComponent::TestCase
  test "a row of hidden segments lit from the left, with the caller's class and segment data" do
    render_inline(GaugeComponent.new(lit: 3, segments: 8, class: "hub-goal__gauge", segment_data: { countdown_target: "segment" }))

    assert_selector ".gauge.hub-goal__gauge[aria-hidden=true] > .gauge__segment[data-countdown-target=segment]", count: 8
    assert_selector ".gauge__segment--lit", count: 3
    assert_selector ".gauge__segment:nth-child(3).gauge__segment--lit"
    assert_no_selector ".gauge__segment:nth-child(4).gauge__segment--lit"
  end

  test "lights whole segments for a share of the maximum, clamped, and none without a maximum" do
    assert_equal 0, GaugeComponent.lit(3_599, 86_400)
    assert_equal 22, GaugeComponent.lit(81_015, 86_400)
    assert_equal 24, GaugeComponent.lit(9_000, 5_000)
    assert_equal 0, GaugeComponent.lit(-10, 5_000)
    assert_equal 0, GaugeComponent.lit(10, 0)
  end
end

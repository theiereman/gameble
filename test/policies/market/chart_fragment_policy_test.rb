require "test_helper"

class Market::ChartFragmentPolicyTest < ActiveSupport::TestCase
  test "anyone may ask for a chart fragment, which answers only while its chart is published" do
    assert Market::ChartFragmentPolicy.new(nil, %i[market chart_fragment]).show?
  end
end

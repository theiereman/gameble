require "test_helper"

class AltSignalSentenceComponentTest < ViewComponent::TestCase
  def sentence(signal, facts) = render_inline(AltSignalSentenceComponent.new(signal:, facts:)).text

  test "near-maximum opening reads its days and its peak" do
    assert_equal "Opened 120 capsules or more a day on 3 of the last 7 days, up to 135 in one day.",
      sentence("near_maximum_opening", { "days" => 3, "peak" => 135, "per_day" => 120 })
  end

  test "one-way trades read their count and copies, with thousands separated" do
    assert_equal "Trades in the last 7 days where it gave far more than it got: 12. Copies given: 1,200, received: 300.",
      sentence("one_way_trades", { "trades" => 12, "given" => 1200, "received" => 300 })
  end

  test "the French sentence is written too" do
    I18n.with_locale(:fr) do
      assert_match(/Échanges des 7 derniers jours/, sentence("one_way_trades", { "trades" => 12, "given" => 48, "received" => 12 }))
    end
  end
end

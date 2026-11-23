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

  test "sales outside the market price read their count and both directions" do
    assert_equal "Sold to the other account in the last 30 days at under half or over twice the edition's average price: 3 (2 below, 1 above).",
      sentence("sales_outside_price", { "sales" => 3, "below" => 2, "above" => 1 })
  end

  test "minimum-price sales read their count" do
    assert_equal "Sold to the other account at the minimum price in the last 30 days: 4.", sentence("minimum_price_sales", { "sales" => 4 })
  end

  test "bids on a tied seller read the listings and the bids" do
    assert_equal "Bids on the other account's listings, which another signal ties to it, in the last 30 days. Listings: 2, bids: 5.",
      sentence("bids_on_tied_seller", { "listings" => 2, "bids" => 5 })
  end

  test "an Archive purchase of a tied deposit reads its card, its season undelimited and its deposit day" do
    facts = { "card" => "tin-soldier", "season" => 1979, "price" => 1500, "deposited" => 2, "deposited_on" => "2026-11-03" }

    assert_equal "Bought tin-soldier (season 1979) from the Archives for 1,500 PiCoins in the last 30 days; the other account, which another signal ties " \
      "to it, entrusted that edition. Copies entrusted: 2, last on November 3, 2026.", sentence("archive_purchase_of_tied_deposit", facts)
    I18n.with_locale(:fr) do
      assert_match(/\(saison 1979\).*la dernière fois le 1er novembre 2026\.\z/, sentence("archive_purchase_of_tied_deposit", facts.merge("deposited_on" => "2026-11-01")))
    end
  end

  test "every signal has a sentence and a name in both languages" do
    %i[en fr].each do |locale|
      Game::Market::AltSignals::SIGNALS.each do |signal|
        assert I18n.exists?("back_office.market_signals.sentences.#{signal}", locale), "#{locale} sentence of #{signal}"
        assert I18n.exists?("back_office.market_signals.signals.#{signal}", locale), "#{locale} name of #{signal}"
      end
      Game::Market::AltSignals::TYING.each do |signal|
        assert I18n.exists?("back_office.market_signals.tie_sentences.#{signal}", locale), "#{locale} tie sentence of #{signal}"
      end
    end
  end

  test "a tie reads its facts between the two accounts" do
    assert_equal "Sales between the two accounts at the minimum price in the last 30 days: 4.",
      render_inline(AltSignalSentenceComponent.new(signal: "minimum_price_sales", facts: { "sales" => 4 }, tie: true)).text
  end

  test "the French sentence is written too" do
    I18n.with_locale(:fr) do
      assert_match(/Échanges des 7 derniers jours/, sentence("one_way_trades", { "trades" => 12, "given" => 48, "received" => 12 }))
    end
  end
end

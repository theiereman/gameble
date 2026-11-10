require "application_system_test_case"
require_relative "../support/market"

class MarketRulesPagesTest < ApplicationSystemTestCase
  include MarketSettings

  PHONE = [ 390, 844 ].freeze

  setup { Game::Market::Settings.delete_all }

  test "a visitor reads the real-money clause and the market deletion paragraph on the legal page" do
    visit legal_path(locale: :en)

    assert_selector ".legal__real-money", text: I18n.t("pages.legal.terms.real_money", locale: :en)
    assert_selector ".legal__market-deletion", text: /PiCoin balance is destroyed without refund/
  end

  test "on a phone the market table of Comment ça marche fits the page" do
    window = page.driver.browser.manage.window
    original = window.size
    window.resize_to(*PHONE)
    open_market!(first_opened_at: Time.current)

    visit how_it_works_path(locale: :en)

    assert_selector "[data-market='rarities'] tbody tr", count: 5
    eventually("the market table fits the page") { page.evaluate_script("document.documentElement.scrollWidth <= window.innerWidth") }
  ensure
    window.resize_to(*original) if original
  end
end

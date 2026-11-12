require "test_helper"
require_relative "../../support/hidden_back_office"
require_relative "../../support/market"
require_relative "../../support/steam_sign_in"

module BackOffice
  class ChartPublicationsControllerTest < ActionDispatch::IntegrationTest
    include HiddenBackOffice
    include MarketSettings
    include SteamSignIn

    setup do
      Game::Market::ChartPublication.delete_all
      open_market!(first_opened_at: 3.days.ago)
    end

    def published_kinds = Game::Market::ChartPublications.published_kinds

    test "an administrator publishes then unpublishes a chart, back on the market page with the change announced" do
      sign_in(accounts_players(:administrator))

      post back_office_publish_chart_path(locale: :en, kind: "reactor")

      assert_redirected_to back_office_market_path(locale: :en, anchor: "chart-switches")
      assert_equal "The Reactor is public.", flash[:notice]
      assert_equal [ "reactor" ], published_kinds
      follow_redirect!
      assert_select "[role=switch][data-chart-switch=reactor][aria-checked=true][autofocus]"
      assert_select "#chart-switch-reactor-state", /public since/

      post back_office_unpublish_chart_path(locale: :en, kind: "reactor")

      assert_equal "The Reactor is visible to staff only.", flash[:notice]
      assert_empty published_kinds
    end

    test "the market page shows one switch per public chart, each off and staff only at first, with the publish dialog" do
      sign_in(accounts_players(:administrator))

      get back_office_market_path(locale: :fr)

      assert_select "#chart-switches h2", "GRAPHES PUBLICS"
      assert_select "button[role=switch][aria-checked=false]", 3
      assert_select "button[role=switch][aria-haspopup=dialog][data-chart-switch=reactor]", "Le Réacteur"
      assert_select "#chart-switch-reactor-state", "staff seulement"
      assert_select "dialog#chart-publish-reactor form[action=?]", back_office_publish_chart_path(locale: :fr, kind: "reactor")
      assert_select "[aria-disabled]", false
      assert_select "[style]", false
    end

    test "a published switch posts its unpublication at once, without a dialog" do
      Game::Market::PublishChart.new.call(player: accounts_players(:administrator), kind: "rarity_prices")
      sign_in(accounts_players(:administrator))

      get back_office_market_path(locale: :en)

      assert_select "form[action=?] button[type=submit][role=switch][aria-checked=true]", back_office_unpublish_chart_path(locale: :en, kind: "rarity_prices")
      assert_select "dialog#chart-publish-rarity-prices", false
    end

    test "a moderator sees the switches disabled with the reason, and cannot switch them" do
      sign_in(accounts_players(:moderator))

      get back_office_market_path(locale: :en)

      assert_select "button[role=switch][aria-disabled=true]", 3
      assert_select "button[role=switch][aria-describedby~=chart-switches-reason]", 3
      assert_select "#chart-switches-reason", "Only an administrator can publish or unpublish a chart."
      assert_select "dialog[id^=chart-publish]", false

      post back_office_publish_chart_path(locale: :en, kind: "reactor")

      assert_response :forbidden
      assert_empty published_kinds
    end

    test "a player and a visitor find no switch" do
      sign_in(accounts_players(:player))

      post back_office_publish_chart_path(locale: :en, kind: "reactor")

      assert_unknown_address
      assert_empty published_kinds
    end
  end
end

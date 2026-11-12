require "application_system_test_case"
require_relative "../support/market"
require_relative "../support/market_snapshots"
require_relative "../support/steam_sign_in"

class ChartPublicationTest < ApplicationSystemTestCase
  include MarketSettings
  include MarketSnapshots
  include SteamSignIn

  setup do
    clear_snapshots
    Game::Market::ChartPublication.delete_all
    open_market!(first_opened_at: 40.days.ago)
    snapshot!(Time.current.utc.to_date - 1, created: 10_000, destroyed_total: 5_600, circulation: 400_000)
  end

  teardown { clear_snapshots }

  def sign_in_as(player)
    mock_steam_sign_in(player.steam_id)
    visit home_path(locale: :en)
    click_steam_sign_in
    assert_signed_in
  end

  test "an administrator publishes the Reactor, a visitor reaches it from the market, and loses it once unpublished" do
    sign_in_as(accounts_players(:administrator))
    visit back_office_market_path(locale: :en)

    switch = find("[role=switch][data-chart-switch=reactor]")
    assert_equal "false", switch["aria-checked"]
    switch.click
    within("dialog#chart-publish-reactor") do
      assert_text(/Publish The Reactor for every player\?/i)
      click_on "PUBLISH"
    end

    assert_text "The Reactor is public."
    assert_selector "[role=switch][data-chart-switch=reactor][aria-checked=true]", focused: true
    assert_selector "#chart-switch-reactor-state", text: "public since"

    sign_out
    assert_signed_out
    visit market_path(locale: :en)
    click_on "THE BROTHERHOOD'S EXCHANGE"
    assert_selector "h1", text: "The Brotherhood's Exchange"
    assert_selector "#reactor-flows"
    assert_no_text "VISIBLE TO STAFF"

    sign_in_as(accounts_players(:administrator))
    visit back_office_market_path(locale: :en)
    find("[role=switch][data-chart-switch=reactor]").click
    assert_text "The Reactor is visible to staff only."
    assert_selector "[role=switch][data-chart-switch=reactor][aria-checked=false]", focused: true

    sign_out
    assert_signed_out
    visit market_path(locale: :en)
    assert_no_link "THE BROTHERHOOD'S EXCHANGE"
    visit market_exchange_path(locale: :en)
    assert_text "RecordNotFound"
  end

  test "a moderator sees the switches disabled with the reason" do
    sign_in_as(accounts_players(:moderator))
    visit back_office_market_path(locale: :en)

    assert_selector "[role=switch][aria-disabled=true]", count: 3
    assert_text "Only an administrator can publish or unpublish a chart."
    find("[role=switch][data-chart-switch=reactor]").click
    assert_no_selector "dialog[open]"
  end
end

require "application_system_test_case"
require_relative "../support/catalog_seeds"

class ModerationTest < ApplicationSystemTestCase
  include CatalogSeeds

  setup do
    publish_sets_draft
    @reported = accounts_players(:player)
    @reported.update_columns(persona_name: "Rude Rick")
    reporter = Accounts::Player.create!(steam_id: "76561197960287931", persona_name: "Polite Paula")
    Accounts::Report.create!(reporter:, reported: @reported, reason: "harassment")
    moderator = accounts_players(:moderator)
    OmniAuth.config.test_mode = true
    OmniAuth.config.mock_auth[:steam] = OmniAuth::AuthHash.new(provider: "steam", uid: "https://steamcommunity.com/openid/id/#{moderator.steam_id}")
  end

  teardown do
    OmniAuth.config.mock_auth.delete(:steam)
    OmniAuth.config.test_mode = false
  end

  test "a moderator bans a reported player from the queue, whose profile is then unavailable; unbanning restores it" do
    visit home_path(locale: :en)
    click_steam_sign_in
    assert_signed_in

    visit back_office_path(locale: :en)
    click_on "The reports"
    within("[data-reported='#{@reported.token}']") do
      assert_text "Harassment"
      assert_text "Polite Paula"
      accept_confirm { click_on "Ban Rude Rick" }
    end

    assert_text "The player is banned, officer."
    assert_no_selector "[data-reported='#{@reported.token}']"
    assert_selector "[data-banned='#{@reported.token}']", text: "Rude Rick"

    visit brother_path(locale: :en, token: @reported.token)
    assert_selector "h1", text: "Profile not available"
    assert_no_text "Rude Rick"

    visit back_office_reports_path(locale: :en)
    within("[data-banned='#{@reported.token}']") do
      accept_confirm { click_on "Unban Rude Rick" }
    end

    assert_text "The ban is lifted, officer."
    assert_no_selector "[data-banned='#{@reported.token}']"
    assert_selector "[data-reported='#{@reported.token}']"

    click_on "Rude Rick"
    assert_current_path brother_path(locale: :en, token: @reported.token)
    assert_selector "h1", text: "Rude Rick"
  end
end

require "application_system_test_case"
require_relative "../support/catalog_seeds"

# The library from the attic's lectern (CAP-6, story 4.1): a player sees the
# season's tomes with their owned / total and moves between the tabs; a
# visitor sees the same sets at 0.
class LibraryTest < ApplicationSystemTestCase
  include CatalogSeeds

  setup do
    @season = publish_sets_draft
    @player = accounts_players(:player)
    tome = Catalog::Set.find_by!(season_id: @season.id, key: "action-1")
    Catalog::SetMembership.where(set_id: tome.id).order(:position).limit(3).pluck(:card_season_id).each do |card_season_id|
      Game::Holding.create!(player_id: @player.id, card_season_id:, quantity: 1)
    end
    OmniAuth.config.test_mode = true
    OmniAuth.config.mock_auth[:steam] = OmniAuth::AuthHash.new(provider: "steam", uid: "https://steamcommunity.com/openid/id/#{@player.steam_id}")
  end

  teardown do
    OmniAuth.config.mock_auth.delete(:steam)
    OmniAuth.config.test_mode = false
  end

  test "a player walks from the lectern to the library, its tabs and back to the attic" do
    visit home_path(locale: :en)
    click_on "Enlist through Steam"
    assert_button "Stand down"

    click_on "Library"

    assert_current_path library_path(locale: :en)
    assert_selector "h1", text: "The library of the Brotherhood"
    within(".shelf .tome", match: :first) do
      assert_text "Action · Tome 1"
      assert_text "3 / 25"
    end
    assert_selector ".shelf .tome", count: 4
    take_screenshot

    click_on "Publishers"
    assert_selector ".library__tab[aria-current=page]", text: "Publishers"
    assert_selector ".shelf .tome", text: "P\n0 / 5"

    click_on "Best rated of the year"
    assert_selector ".shelf .tome", count: 3
    assert_selector ".shelf .tome", match: :first, text: "Best rated of 2015"

    click_on "Back to the attic"
    assert_current_path home_path(locale: :en)
  end

  test "a visitor reaches the library from the lectern by keyboard and sees every set at 0" do
    visit home_path(locale: :fr)

    find(".attic__link").send_keys(:enter)

    assert_current_path library_path(locale: :fr)
    assert_selector ".shelf .tome", count: 4
    assert_equal [ "0 / 25", "0 / 25", "0 / 25", "0 / 44" ], all(".shelf .tome__count").map(&:text)
  end

  test "on a phone the shelf fits the screen" do
    page.driver.browser.manage.window.resize_to(390, 844)
    visit library_path(locale: :en)

    assert_selector ".shelf .tome", count: 4
    assert page.evaluate_script("document.documentElement.scrollWidth <= window.innerWidth"), "the page should not scroll sideways"
    take_screenshot
  ensure
    page.driver.browser.manage.window.resize_to(*SCREEN_SIZE)
  end
end

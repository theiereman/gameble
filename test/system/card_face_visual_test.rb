require "application_system_test_case"
require_relative "../support/card_baselines"
require_relative "../support/game_packs"

# The card face, pixel for pixel (story "Single card face"): tilted under a
# resting pointer, at each size in the back-office preview and revealed in a
# freshly opened pack, compared with committed baselines
# (test/fixtures/files/card_faces/; UPDATE_CARD_BASELINES=1 rewrites them).
# The rare sample carries no infinite effect outside the booster; the
# revealed card is a common one, whose booster face has none either, and
# whose fixture cover is unreachable, so it shows the missing image.
class CardFaceVisualTest < ApplicationSystemTestCase
  include CardBaselines
  include GamePacks

  PHONE = [ 390, 844 ].freeze

  setup do
    OmniAuth.config.test_mode = true
    page.driver.browser.execute_cdp("Emulation.setEmulatedMedia", features: [ { name: "prefers-reduced-motion", value: "" } ])
  end

  teardown do
    OmniAuth.config.mock_auth.delete(:steam)
    OmniAuth.config.test_mode = false
    page.driver.browser.manage.window.resize_to(*SCREEN_SIZE)
  end

  def sign_in(player)
    OmniAuth.config.mock_auth[:steam] = OmniAuth::AuthHash.new(provider: "steam", uid: "https://steamcommunity.com/openid/id/#{player.steam_id}")
    visit home_path(locale: :en)
    click_steam_sign_in
    assert_signed_in
  end

  # Rests the pointer at 25 % across and 25 % down the card.
  def rest_pointer_on(card)
    width, height = card.evaluate_script("[ this.offsetWidth, this.offsetHeight ]")
    page.driver.browser.action.move_to(card.native, -(width / 4), -(height / 4)).perform
  end

  def assert_tilted(card)
    card.assert_matches_selector("[data-tilt=held]")
    transform = card.evaluate_script("getComputedStyle(this).transform")
    assert_match(/\Amatrix3d\(/, transform, "the tilt should be 3D")
  end

  test "the rare face, tilted at each size, matches its baseline" do
    sign_in(accounts_players(:administrator))
    visit back_office_cards_path(locale: :en)

    %w[s m l xl].each do |size|
      specimen = find("[data-specimen=rare-#{size}]")
      scroll_to(specimen, align: :center)
      card = specimen.find(".card")
      card.find(".card__art[data-art=drawn]", visible: :all)
      rest_pointer_on(card)

      assert_tilted(card)
      assert_card_settled(card)
      assert_matches_card_baseline(specimen, "tilted-#{size}")
    end
  end

  [ [ "m", nil ], [ "xl", PHONE ] ].each do |size, window|
    test "a revealed face tilts under the pointer and matches its baseline at #{size}" do
      page.driver.browser.manage.window.resize_to(*window) if window
      player = accounts_players(:player)
      sign_in(player)
      create_pack(player, cards: fixture_tier_ids, available_at: 1.day.ago)
      visit home_path(locale: :en)
      # Menu 01 on desktop; the empty showcase's button on a phone, where
      # the menu is hidden.
      if has_css?(".hub-menu", wait: 0)
        find(".hub-menu .menu-item[aria-keyshortcuts='1']").click
      else
        within(".hub-showcase--empty") { click_on "Open a booster" }
      end
      assert_selector ".pack-reveal"

      button = find(".pack-reveal__item:nth-child(1) .reveal-card")
      button.click
      assert_selector ".pack-reveal__item:nth-child(1) .reveal-card[data-state=flipped]:not([data-playing])", wait: 5
      card = find(".pack-reveal__item:nth-child(1) .reveal-card__face .card.card--#{size}.card--booster")
      assert_selector ".pack-reveal__item:nth-child(1) .reveal-card__face .card__title", text: "TIN SOLDIER"
      card.find(".card__art[data-art]", visible: :all)
      rest_pointer_on(card)

      assert_tilted(card)
      assert_card_settled(card)
      assert_matches_card_baseline(button, "revealed-#{size}")
    end
  end
end

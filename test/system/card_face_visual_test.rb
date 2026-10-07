require "application_system_test_case"
require_relative "../support/card_baselines"
require_relative "../support/game_packs"

# The card face, pixel for pixel (story "Single card face"): tilted under a
# resting pointer, at each size in the back-office preview and revealed in
# the booster (the desktop row, m; the phone's pile, xl, story 8.12),
# compared with committed baselines
# (test/fixtures/files/card_faces/; UPDATE_CARD_BASELINES=1 rewrites them).
# The rare sample carries no infinite effect outside the booster; the
# revealed card is a common one, whose booster face has none either, and
# whose fixture cover is unreachable, so it shows the missing image.
class CardFaceVisualTest < ApplicationSystemTestCase
  include CardBaselines
  include GamePacks

  setup do
    OmniAuth.config.test_mode = true
    page.driver.browser.execute_cdp("Emulation.setEmulatedMedia", features: [ { name: "prefers-reduced-motion", value: "" } ])
  end

  teardown do
    OmniAuth.config.mock_auth.delete(:steam)
    OmniAuth.config.test_mode = false
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

    # The long title at xl: two VT323 lines inside the band.
    specimen = find("[data-specimen=epic-xl]")
    scroll_to(specimen, align: :center)
    card = specimen.find(".card")
    card.find(".card__art[data-art=drawn]", visible: :all)
    rest_pointer_on(card)

    assert_tilted(card)
    assert_card_settled(card)
    assert_matches_card_baseline(specimen, "tilted-xl-long")
  end

  test "a revealed face in the booster tilts under the pointer and matches its baseline at m" do
    player = accounts_players(:player)
    sign_in(player)
    create_pack(player, cards: fixture_tier_ids, available_at: 1.day.ago)
    visit booster_path(locale: :en)

    find(".booster-canister").click
    assert_selector ".booster-card[data-dealt]", count: 5, wait: 10
    assert_selector ".booster__state", text: /\AINVENTORY\z/
    find(".booster-card:nth-child(1) .booster-card__hit").click
    assert_selector ".booster-card:nth-child(1)[data-revealed] .booster-card__flip.is-up"
    # The reveal over: the navigation unlocked, the burst gone.
    assert_selector ".booster__back:not([aria-disabled])", wait: 5
    assert_selector ".booster-card:nth-child(1) .booster-card__fx:empty", visible: :all
    card = find(".booster-card:nth-child(1) .booster-card__front .card.card--m.card--booster")
    assert_selector ".booster-card:nth-child(1) .booster-card__front .card__title", text: "TIN SOLDIER"
    card.find(".card__art[data-art]", visible: :all)
    rest_pointer_on(card)

    assert_tilted(card)
    assert_card_settled(card)
    slot = find(".booster-card:nth-child(1) .booster-card__frame")
    page.document.synchronize(5) do
      raise Capybara::ExpectationNotMet, "the slot is still moving" unless slot.evaluate_script("this.getAnimations({ subtree: true }).length === 0")
    end
    assert_matches_card_baseline(slot, "revealed-m")
  end

  test "a revealed face on the phone's pile tilts under the pointer and matches its baseline at xl" do
    page.driver.browser.manage.window.resize_to(390, 844)
    player = accounts_players(:player)
    sign_in(player)
    create_pack(player, cards: fixture_tier_ids, available_at: 1.day.ago)
    visit booster_path(locale: :en)

    find(".booster-canister").click
    assert_selector ".booster[data-layout=phone] .booster__pile .booster-card[data-dealt]", count: 5, wait: 10
    assert_selector ".booster__state", text: /\AINVENTORY\z/
    top = ".booster-card[data-position='1']"
    find("#{top} .booster-card__hit").click
    assert_selector "#{top}[data-revealed][data-top] .booster-card__flip.is-up"
    # The reveal over: the navigation unlocked, the burst gone.
    assert_selector ".booster__back:not([aria-disabled])", wait: 5
    assert_selector "#{top} .booster-card__fx:empty", visible: :all
    card = find("#{top} .booster-card__front .card.card--xl.card--booster")
    assert_selector "#{top} .booster-card__front .card__title", text: "TIN SOLDIER"
    card.find(".card__art[data-art]", visible: :all)
    rest_pointer_on(card)

    assert_tilted(card)
    assert_card_settled(card)
    slot = find("#{top} .booster-card__frame")
    page.document.synchronize(5) do
      raise Capybara::ExpectationNotMet, "the slot is still moving" unless slot.evaluate_script("this.getAnimations({ subtree: true }).length === 0")
    end
    assert_matches_card_baseline(slot, "revealed-xl")
  end
end

require "application_system_test_case"
require_relative "../support/game_packs"

# The settings screen and the one motion switch (story 10.4; EXPERIENCE.md,
# Reduced motion; AD-27): "Animations réduites" is SYSTÈME / OUI / NON, kept
# on the player and mirrored in a cookie; the server renders it as
# `html[data-motion=reduced]` (and drops the view-transition meta), and CSS,
# Stimulus and the islands all read that one attribute: nothing loops and
# nothing slides, signed in or out, and the switch is live.
class SettingsTest < ApplicationSystemTestCase
  include GamePacks

  setup do
    @player = accounts_players(:player)
    OmniAuth.config.test_mode = true
    OmniAuth.config.mock_auth[:steam] = OmniAuth::AuthHash.new(provider: "steam", uid: "https://steamcommunity.com/openid/id/#{@player.steam_id}")
  end

  teardown do
    OmniAuth.config.mock_auth.delete(:steam)
    OmniAuth.config.test_mode = false
  end

  def sign_in(path = nil)
    visit home_path(locale: :en)
    click_steam_sign_in
    assert_signed_in
    visit path if path
  end

  def forced? = page.evaluate_script("document.documentElement.dataset.motion") == "reduced"

  def view_transition_meta? = page.evaluate_script("document.querySelector('meta[name=view-transition]') !== null")

  # Infinite animations running on the page, by what animates.
  def loops
    page.evaluate_script(<<~JS)
      document.getAnimations()
        .filter((animation) => animation.playState === "running" && animation.effect.getComputedTiming().iterations === Infinity)
        .map((animation) => animation.animationName || animation.transitionProperty || "?")
    JS
  end

  def choose_motion(label)
    within("[role=group][aria-labelledby=settings-motion]") { click_on label }
    assert_selector "button[aria-pressed=true]", text: /\A#{label}\z/i
  end

  test "a player sets the profile visibility at once, and a signed-out visitor then finds the profile unavailable" do
    sign_in settings_path(locale: :en)
    assert_selector "button[name=visibility][aria-pressed=true]", text: "PUBLIC"

    within("[role=group][aria-labelledby=settings-visibility]") { click_on "Private" }
    assert_selector "button[name=visibility][aria-pressed=true]", text: "PRIVATE"
    assert_equal "private", @player.reload.visibility

    using_session("visitor") do
      visit brother_path(locale: :en, token: @player.token)
      assert_text "Profile not available"
    end
  end

  test "a player picks reduced motion on the settings screen, and the switch follows on every page, signed in and out" do
    sign_in
    find(".top-bar .player-chip__button").click
    within("#player-menu") { click_on "Settings" }
    assert_selector "h1", text: "PROFILE AND SETTINGS"
    assert_selector "button[aria-pressed=true]", text: "SYSTEM"
    assert_not forced?
    assert view_transition_meta?

    choose_motion("Yes")

    assert forced?, "the attribute is rendered by the server after the change"
    assert_not view_transition_meta?, "no view-transition meta when motion is reduced"
    assert_equal true, @player.reload.reduced_motion

    visit home_path(locale: :fr)
    assert forced?
    visit library_path(locale: :en)
    assert forced?

    sign_out
    assert_signed_out
    assert forced?, "the signed-out hub follows the cookie"
    assert_not view_transition_meta?
    visit library_path(locale: :fr)
    assert forced?

    click_steam_sign_in
    assert_signed_in
    assert forced?
    visit settings_path(locale: :en)
    choose_motion("System")
    assert_not forced?
    assert view_transition_meta?
    sign_out
    assert_signed_out
    assert_not forced?
  end

  test "an explicit No is kept too, and the language links switch the screen" do
    sign_in(settings_path(locale: :en))

    choose_motion("No")
    assert_equal false, @player.reload.reduced_motion
    assert_not forced?

    within("[role=group][aria-labelledby=settings-language]") { click_on "Français" }
    assert_selector "h1", text: "PROFIL ET PARAMÈTRES"
    assert_selector "html[lang=fr]", visible: :all
    assert_selector "button[aria-pressed=true]", text: "NON"
  end

  test "sign-out from the settings screen lands on the signed-out hub" do
    sign_in(settings_path(locale: :en))

    click_on "Sign out"

    assert_signed_out
    assert_selector ".hub-invitation"
  end

  test "with the setting on, nothing loops on the hub, the booster screen and a public card page, and the switch is live" do
    create_pack(@player)
    sign_in
    visit booster_path(locale: :en)
    assert_selector ".booster-canister"
    sleep 0.5
    assert_not_empty loops, "the booster screen loops with motion on: the check means something"

    # Live: the attribute alone stops every loop.
    page.execute_script("document.documentElement.dataset.motion = 'reduced'")
    assert_empty loops, "no loop should run with data-motion=reduced"

    @player.update!(reduced_motion: true)
    [ home_path(locale: :en), booster_path(locale: :en), library_path(locale: :en) ].each do |path|
      visit path
      assert forced?, path
      assert_empty loops, path
    end

    sign_out
    assert_signed_out
    visit card_path(locale: :en, slug: "portal")
    assert_selector ".live-marker__dot", visible: :all
    page.execute_script("document.documentElement.dataset.motion = 'reduced'")
    assert_empty loops
  end

  test "a visitor with the cookie set sees no loop on the public card page" do
    visit card_path(locale: :en, slug: "portal")
    assert_selector ".live-marker__dot", visible: :all
    assert_not_empty loops, "the LIVE marker blinks with motion on"

    page.driver.browser.manage.add_cookie(name: "motion", value: "reduced", path: "/")
    visit card_path(locale: :en, slug: "portal")

    assert forced?
    assert_empty loops
    assert_not view_transition_meta?
  end

  test "under the system's reduced motion nothing loops without the setting" do
    page.driver.browser.execute_cdp("Emulation.setEmulatedMedia", features: [ { name: "prefers-reduced-motion", value: "reduce" } ])
    visit card_path(locale: :en, slug: "portal")

    assert_not forced?
    assert_empty loops
  ensure
    page.driver.browser.execute_cdp("Emulation.setEmulatedMedia", features: [ { name: "prefers-reduced-motion", value: "" } ])
  end

  test "on a phone, PLUS leads to the settings screen and its contextual back leads to PLUS" do
    page.driver.browser.manage.window.resize_to(390, 844)
    sign_in

    within(".tab-bar") { click_on "More" }
    assert_selector ".plus__list"
    assert_selector ".tab-bar__tab[aria-current=page]", text: "MORE"
    within(".plus__list") { click_on "Profile and settings" }

    assert_selector "h1", text: "PROFILE AND SETTINGS"
    assert_selector ".tab-bar__tab[aria-current=page]", text: "MORE"
    within(".top-bar") { click_on "More" }
    assert_selector ".plus__list"
  end
end

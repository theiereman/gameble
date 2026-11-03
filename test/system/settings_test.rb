require "application_system_test_case"
require_relative "../support/game_packs"
require_relative "../support/steam_sign_in"

# The settings screen and the one motion switch: "Animations réduites" is
# SYSTÈME / OUI / NON, kept on the player and mirrored in a cookie; the
# server renders OUI as `html[data-motion=reduced]` (and drops the
# view-transition meta) and NON as `html[data-motion=full]`, which overrides
# the system's preference. CSS and Stimulus both read that one
# attribute: nothing loops and nothing slides, signed in or out, and the
# switch is live.
class SettingsTest < ApplicationSystemTestCase
  include GamePacks
  include SteamSignIn

  setup do
    @player = accounts_players(:player)
    mock_steam_sign_in(@player.steam_id)
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

  test "a player deletes their account by typing the word, is signed out, and their profile shows as unavailable" do
    token = @player.token
    sign_in settings_path(locale: :fr)

    click_on "Supprimer mon compte"
    within("dialog#delete-dialog") do
      assert_selector "#delete-dialog-title", text: "SUPPRIMER MON COMPTE"
      submit = find("button[type=submit]")
      assert_predicate submit, :disabled?
      fill_in "Tapez SUPPRIMER pour confirmer", with: "suppr"
      assert_predicate submit, :disabled?
      fill_in "Tapez SUPPRIMER pour confirmer", with: "supprimer"
      assert_not_predicate submit, :disabled?
      click_on "Annuler"
    end
    assert_no_selector "dialog#delete-dialog[open]"
    assert_not @player.reload.deleted?

    click_on "Supprimer mon compte"
    within("dialog#delete-dialog") do
      fill_in "Tapez SUPPRIMER pour confirmer", with: ""
      assert_selector "button[type=submit][disabled]"
      # A paste is an input event too.
      field = find_field("Tapez SUPPRIMER pour confirmer")
      page.execute_script(<<~JS, field)
        arguments[0].value = "Supprimer"
        arguments[0].dispatchEvent(new InputEvent("input", { bubbles: true, inputType: "insertFromPaste" }))
      JS
      assert_selector "button[type=submit]:not([disabled])"
      click_on "Supprimer définitivement"
    end

    assert_signed_out
    assert_selector ".landing-hero"
    assert_text "Votre compte a été supprimé"
    assert_predicate @player.reload, :deleted?

    visit brother_path(locale: :en, token:)
    assert_text(/profile not available/i)
  end

  test "with the setting on, nothing loops on the hub, the booster screen and the library, and the switch is live" do
    create_pack(@player)
    sign_in
    visit booster_path(locale: :en)
    assert_selector ".booster-canister"
    eventually("the booster screen loops with motion on: the check means something") { loops.any? }

    # Live: the attribute alone stops every loop.
    page.execute_script("document.documentElement.dataset.motion = 'reduced'")
    assert_empty loops, "no loop should run with data-motion=reduced"

    @player.update!(reduced_motion: true)
    [ home_path(locale: :en), booster_path(locale: :en), library_path(locale: :en) ].each do |path|
      visit path
      assert forced?, path
      assert_empty loops, path
    end
  end

  test "under the system's reduced motion nothing loops without the setting, and an explicit no brings the loops back" do
    page.driver.browser.execute_cdp("Emulation.setEmulatedMedia", features: [ { name: "prefers-reduced-motion", value: "reduce" } ])
    visit card_path(locale: :en, slug: "portal")

    assert_not forced?
    assert_empty loops

    page.driver.browser.manage.add_cookie(name: "motion", value: "full", path: "/")
    visit card_path(locale: :en, slug: "portal")

    assert_selector "html[data-motion=full] .live-marker__dot", visible: :all
    assert_not_empty loops, "the LIVE marker blinks when the setting asks for full motion"
    assert view_transition_meta?
  ensure
    page.driver.browser.execute_cdp("Emulation.setEmulatedMedia", features: [ { name: "prefers-reduced-motion", value: "" } ])
  end
end

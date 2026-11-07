require "application_system_test_case"
require_relative "../support/catalog_seeds"
require_relative "../support/game_packs"
require_relative "../support/holdings"
require_relative "../support/steam_sign_in"

# The shell's toasts in a real browser: closed by their button or Escape,
# added by a gameble:toast event, and kept in order through a morph refresh.
class ShellTest < ApplicationSystemTestCase
  include CatalogSeeds
  include GamePacks
  include Holdings
  include SteamSignIn

  def sign_in(player, locale: :en)
    mock_steam_sign_in(player.steam_id)
    visit home_path(locale:)
    click_steam_sign_in
    assert_selector ".top-bar .player-chip", visible: :all
    visit home_path(locale:)
  end


  test "a toast closes with its button, and a gameble:toast event adds one" do
    visit settings_path(locale: :en)
    assert_current_path home_path(locale: :en)
    assert_no_selector ".toasts .toast"

    page.execute_script(<<~JS)
      window.dispatchEvent(new CustomEvent("gameble:toast", { detail: { title: "Proposition envoyée", message: "Léa a 7 jours pour répondre." } }))
    JS
    assert_selector ".toasts .toast.toast--notice .toast__title", text: /PROPOSITION ENVOYÉE/i
    assert_selector ".toasts .toast .toast__message", text: "Léa a 7 jours pour répondre."
    find(".toast__close[aria-label=Close]").click
    assert_no_selector ".toasts .toast"
  end

  # Runs Turbo's refresh of the page shown (as the hub's countdown does) and
  # waits for it to finish.
  def refresh_with_turbo
    page.execute_script(<<~JS)
      delete document.documentElement.dataset.testLoaded
      document.addEventListener("turbo:load", () => { document.documentElement.dataset.testLoaded = "" }, { once: true })
      Turbo.visit(location.href, { action: "replace" })
    JS
    assert_selector "html[data-test-loaded]", visible: :all
  end

  test "a toast stays through a morph refresh of the hub" do
    sign_in(accounts_players(:player))
    page.execute_script(<<~JS)
      window.dispatchEvent(new CustomEvent("gameble:toast", { detail: { message: "Still here after the refresh of the page, as long as its time is not up yet, which takes a while." } }))
    JS
    assert_selector ".toasts .toast", text: "Still here"

    refresh_with_turbo
    assert_selector ".toasts .toast", text: "Still here"
  end

  test "several toasts stay through a morph refresh of the hub, in their order" do
    sign_in(accounts_players(:player))
    page.execute_script(<<~JS)
      for (const message of ["First toast, kept through the refresh of the page for a while.", "Second toast, kept through the refresh of the page as well."]) {
        window.dispatchEvent(new CustomEvent("gameble:toast", { detail: { message } }))
      }
    JS
    assert_selector ".toasts .toast", text: "Second toast"

    refresh_with_turbo
    assert_selector ".toasts .toast", text: "First toast"
    assert_selector ".toasts .toast", text: "Second toast"
    messages = all(".toasts .toast__message", text: /kept through/).map(&:text)
    assert_match(/\AFirst toast/i, messages.first)
    assert_match(/\ASecond toast/i, messages.last)
  end

  test "Esc closes the toast that holds the focus" do
    visit home_path(locale: :en)
    page.execute_script(<<~JS)
      window.dispatchEvent(new CustomEvent("gameble:toast", { detail: { message: "Press Esc to close me." } }))
    JS

    find(".toast__close").send_keys(:escape)
    assert_no_selector ".toasts .toast"
  end
end

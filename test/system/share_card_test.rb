require "application_system_test_case"
require_relative "../support/steam_api_stubs"
require_relative "../support/steam_sign_in"

# Sharing a card (CAP-9, story 4.5, redrawn by story 10.3; EXPERIENCE Flow
# 1, Flow 4): a holder opens the "Partager la carte" sheet from the card's
# detail, which copies the link of the card-season's own page on opening; a
# visitor opens it and sees the public card page, only the card, never who
# shared it, then signs in from the pitch's sign-in panel and lands on the
# hub. Where the clipboard cannot be written (plain HTTP), the link is
# selected and copied by execCommand, or the player is told to copy it.
class ShareCardTest < ApplicationSystemTestCase
  include SteamApiStubs
  include SteamSignIn

  setup do
    # A PUBLIC_URL exported in the shell would replace the server's base.
    @public_url = Rails.configuration.x.public_url
    Rails.configuration.x.public_url = nil
    stub_steam_api
    @holder = accounts_players(:player)
    stub_player_summary(@holder.steam_id, "Gabe the Brave")
    Game::Holding.create!(player_id: @holder.id, card_season_id: catalog_card_seasons(:portal_one).id, quantity: 1)
  end

  teardown do
    unstub_steam_api
    Rails.configuration.x.public_url = @public_url
  end

  def sign_in(player)
    mock_steam_sign_in(player.steam_id)
    visit home_path(locale: :en)
    click_steam_sign_in
    assert_signed_in
  end

  # The clipboard as a secure page sees it, recording what is written.
  def stub_clipboard(result: "Promise.resolve()")
    execute_script(<<~JS)
      window.copiedText = null
      Object.defineProperty(navigator, "clipboard", { configurable: true,
        value: { writeText: (text) => { window.copiedText = text; return #{result} } } })
    JS
  end

  # No clipboard (plain HTTP), and execCommand answering `copied`.
  def stub_no_clipboard(copied:)
    execute_script(<<~JS)
      Object.defineProperty(navigator, "clipboard", { configurable: true, value: undefined })
      document.execCommand = () => #{copied}
    JS
  end

  def assert_no_sideways_scroll
    assert page.evaluate_script("document.documentElement.scrollWidth <= window.innerWidth"), "the page should not scroll sideways"
  end

  def status = find("#share-sheet [role=status]", visible: :all)

  # Whether the link's field has the focus with its whole text selected.
  def link_selected?
    evaluate_script(<<~JS)
      (() => {
        const input = document.querySelector("#share-sheet-url")
        return document.activeElement === input && input.selectionStart === 0 && input.selectionEnd === input.value.length
      })()
    JS
  end

  test "a holder opens the sheet, which copies the link; a visitor opens it, then signs in from the pitch and lands on the hub" do
    sign_in(@holder)
    visit card_path(locale: :en, slug: "portal")
    stub_clipboard

    click_on "Share"

    assert_selector "dialog#share-sheet[open] .modal__title", text: "SHARE THE CARD"
    assert_selector "#share-sheet [role=status]", text: "Link copied"
    url = evaluate_script("window.copiedText")
    assert_equal find("#share-sheet-url").value, url
    assert_match %r{\Ahttp://[^/]+/en/cards/portal/seasons/1\z}, url
    # The thumbnail is the card's face; the sheet carries no game image.
    assert_selector "#share-sheet .share-sheet__thumb .card.card--s"
    assert_no_selector "#share-sheet img"
    assert_selector "#share-sheet .share-sheet__note", text: "without the game's image"
    assert_equal "Copy", find("#share-sheet button[data-action='share#copy']").text.capitalize
    take_screenshot

    # "Copy" copies again; Esc closes the sheet and the focus returns to
    # the opener.
    execute_script("window.copiedText = null")
    within("#share-sheet") { click_on "Copy" }
    assert_equal url, evaluate_script("window.copiedText")
    send_keys :escape
    assert_no_selector "dialog#share-sheet[open]"
    assert_equal "Share", evaluate_script("document.activeElement.textContent.trim()")

    sign_out
    assert_signed_out
    visit url

    assert_title "Portal — Epic"
    assert_selector "main > .public-card h1", text: "Portal"
    assert_selector ".public-card .card.card--xl"
    assert_selector ".public-card__pitch", text: "Open capsules, complete sets, trade with your friends."
    assert_selector ".public-card__pitch", text: "Your Steam games, as collectible cards."
    assert_no_selector ".public-card__update"
    assert_selector ".public-card__live-title", text: /LIVE/
    assert_no_selector ".card-detail"
    assert_no_selector "#share-sheet", visible: :all
    assert_no_selector ".card-detail__copies"
    assert_no_selector ".library"
    assert_no_selector "nav.tab-bar"
    assert_no_text "Gabe the Brave"
    take_screenshot

    newcomer = accounts_players(:moderator)
    mock_steam_sign_in(newcomer.steam_id)
    within(".public-card__pitch") { click_on "Open my first capsules" }

    assert_signed_in
    assert_current_path "/en"
    assert_selector ".hub__title", text: "COMMAND BRIDGE"
  end

  test "a visitor follows the public card page's wordmark to the landing" do
    visit card_path(locale: :en, slug: "portal")

    find("a.top-bar__brand").click

    assert_current_path "/en"
    assert_selector ".landing"
  end

  test "a visitor follows the public card page's footer link to the legal page" do
    visit card_path(locale: :en, slug: "portal")

    within(".public-card__footer") { click_on "Legal notice" }

    assert_current_path "/en/legal"
    assert_selector "h1#legal-heading", text: /legal notice/i
    assert_selector ".legal__ownership", text: "All artwork belongs to the games' publishers and their artists, whom we respect."
  end

  test "on a 360 × 740 phone the public card page is one column, with no tab bar and no sideways scroll; the sheet is a bottom sheet" do
    page.driver.browser.manage.window.resize_to(360, 740)
    visit card_path(locale: :en, slug: "portal")

    assert_selector ".public-card .card.card--xl"
    assert_no_selector "nav.tab-bar", visible: :all
    card_top, title_top = evaluate_script(<<~JS)
      (() => {
        const top = (selector) => Math.round(document.querySelector(selector).getBoundingClientRect().top)
        return [ top(".public-card .card"), top(".public-card__title") ]
      })()
    JS
    assert_operator title_top, :>, card_top
    assert_no_sideways_scroll
    take_screenshot

    sign_in(@holder)
    visit card_path(locale: :en, slug: "portal")
    stub_clipboard
    click_on "Share"
    assert_selector "dialog#share-sheet[open]"
    assert_no_sideways_scroll
    take_screenshot
  end

  test "without a clipboard the link is selected and copied by execCommand, or the player is told to copy it" do
    sign_in(@holder)
    visit card_path(locale: :en, slug: "portal")

    stub_no_clipboard(copied: false)
    click_on "Share"
    assert_selector "#share-sheet [role=status]", text: "Press Ctrl+C to copy"
    assert link_selected?, "the link should be selected"

    stub_no_clipboard(copied: true)
    within("#share-sheet") { click_on "Copy" }
    assert_selector "#share-sheet [role=status]", text: "Link copied"

    # The browser refuses the clipboard: execCommand, then the hint.
    execute_script("document.execCommand = () => false")
    stub_clipboard(result: "Promise.reject(new Error('denied'))")
    within("#share-sheet") { click_on "Copy" }
    assert_selector "#share-sheet [role=status]", text: "Press Ctrl+C to copy"
    assert link_selected?, "the link should be selected"
  end

  test "the feedback is gone when the page comes back" do
    sign_in(@holder)
    visit card_path(locale: :en, slug: "portal")
    stub_clipboard
    click_on "Share"
    assert_selector "#share-sheet [role=status]", text: "Link copied"

    send_keys :escape
    assert_no_selector "dialog#share-sheet[open]"
    find(".top-bar__home").click
    assert_current_path "/en"
    go_back

    assert_selector ".card-detail h1", text: "Portal"
    assert_no_selector "dialog#share-sheet[open]"
    assert_equal "", status.text(:all)
  end
end

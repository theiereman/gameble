require "application_system_test_case"
require_relative "../support/steam_api_stubs"
require_relative "../support/steam_sign_in"

# Sharing a card: a holder opens the "Partager la carte" sheet from the card's
# detail, which copies the link of the card-season's own page on opening.
# Where the clipboard cannot be written (plain HTTP), the link is selected
# and copied by execCommand, or the player is told to copy it.
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

  test "a holder opens the sheet, which copies the link, copies it again, and gives the focus back once closed" do
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

    # "Copy" copies again; Esc closes the sheet and the focus returns to
    # the opener.
    execute_script("window.copiedText = null")
    within("#share-sheet") { click_on "Copy" }
    assert_equal url, evaluate_script("window.copiedText")
    send_keys :escape
    assert_no_selector "dialog#share-sheet[open]"
    assert_selector ":focus", text: /\AShare\z/i
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
end

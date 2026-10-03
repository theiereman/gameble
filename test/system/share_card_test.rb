require "application_system_test_case"
require_relative "../support/steam_api_stubs"

# Sharing a card (CAP-9, story 4.5; EXPERIENCE Flow 1): a holder copies the
# link from the card's detail, the card-season's own page; a visitor opens
# it and sees only the card, never who shared it, then signs in from the
# invitation and lands in the attic. Where the clipboard cannot be written
# (plain HTTP), the link is selected and copied by execCommand, or the
# player is told to copy it.
class ShareCardTest < ApplicationSystemTestCase
  include SteamApiStubs

  setup do
    # A PUBLIC_URL exported in the shell would replace the server's base.
    @public_url = Rails.configuration.x.public_url
    Rails.configuration.x.public_url = nil
    stub_steam_api
    @holder = accounts_players(:player)
    stub_player_summary(@holder.steam_id, "Gabe the Brave")
    Game::Holding.create!(player_id: @holder.id, card_season_id: catalog_card_seasons(:portal_one).id, quantity: 1)
    OmniAuth.config.test_mode = true
  end

  teardown do
    OmniAuth.config.mock_auth.delete(:steam)
    OmniAuth.config.test_mode = false
    unstub_steam_api
    Rails.configuration.x.public_url = @public_url
  end

  def sign_in(player)
    OmniAuth.config.mock_auth[:steam] = OmniAuth::AuthHash.new(provider: "steam", uid: "https://steamcommunity.com/openid/id/#{player.steam_id}")
    visit home_path(locale: :en)
    click_on "Enlist through Steam"
    assert_button "Stand down"
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

  def status = find(".card-detail__share [role=status]", visible: :all)

  # Whether the link's field has the focus with its whole text selected.
  def link_selected?
    evaluate_script(<<~JS)
      (() => {
        const input = document.querySelector(".card-detail__share-url")
        return document.activeElement === input && input.selectionStart === 0 && input.selectionEnd === input.value.length
      })()
    JS
  end

  test "a holder copies the link; a visitor opens it, then signs in from the invitation and lands in the attic" do
    sign_in(@holder)
    visit card_path(locale: :en, slug: "portal")
    stub_clipboard

    click_on "Share this card"

    assert_selector ".card-detail__share [role=status]", text: "Link copied"
    url = evaluate_script("window.copiedText")
    assert_equal find(".card-detail__share-url").value, url
    assert_match %r{\Ahttp://[^/]+/en/cards/portal/seasons/1\z}, url
    take_screenshot

    click_on "Stand down"
    assert_button "Enlist through Steam"
    visit url

    assert_title "Portal — Amethyst"
    assert_selector "main > .card-detail h1", text: "Portal"
    assert_selector ".card-detail__invitation", text: "Ten packs wait in the attic"
    assert_no_selector ".card-detail__share"
    assert_no_selector ".card-detail__copies"
    assert_no_selector ".library"
    assert_no_text "Gabe the Brave"
    take_screenshot

    newcomer = accounts_players(:moderator)
    OmniAuth.config.mock_auth[:steam] = OmniAuth::AuthHash.new(provider: "steam", uid: "https://steamcommunity.com/openid/id/#{newcomer.steam_id}")
    within(".card-detail__invitation") { click_on "Claim them through Steam" }

    assert_button "Stand down"
    assert_current_path "/en"
    assert_selector "#attic-heading", visible: :all
  end

  test "without a clipboard the link is selected and copied by execCommand, or the player is told to copy it" do
    sign_in(@holder)
    visit card_path(locale: :en, slug: "portal")

    stub_no_clipboard(copied: false)
    click_on "Share this card"
    assert_selector ".card-detail__share [role=status]", text: "Press Ctrl+C to copy"
    assert link_selected?, "the link should be selected"

    stub_no_clipboard(copied: true)
    click_on "Share this card"
    assert_selector ".card-detail__share [role=status]", text: "Link copied"

    # The browser refuses the clipboard: execCommand, then the hint.
    execute_script("document.execCommand = () => false")
    stub_clipboard(result: "Promise.reject(new Error('denied'))")
    click_on "Share this card"
    assert_selector ".card-detail__share [role=status]", text: "Press Ctrl+C to copy"
    assert link_selected?, "the link should be selected"
  end

  test "the feedback is gone when the page comes back" do
    sign_in(@holder)
    visit card_path(locale: :en, slug: "portal")
    stub_clipboard
    click_on "Share this card"
    assert_selector ".card-detail__share [role=status]", text: "Link copied"

    click_on "Back to the attic"
    assert_current_path "/en"
    go_back

    assert_selector ".card-detail h1", text: "Portal"
    assert_equal "", status.text(:all)
  end
end

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
      assert_text(/profile not available/i)
    end
  end

  test "with trades open, going private asks first, then cancels them" do
    portal = catalog_card_seasons(:portal_one).id
    depths = catalog_card_seasons(:rare_card_one).id
    Game::Holding.create!(player_id: @player.id, card_season_id: portal, quantity: 2)
    [ accounts_players(:moderator), accounts_players(:administrator) ].each do |friend|
      Game::Friendship.create!(low_player_id: [ @player.id, friend.id ].min, high_player_id: [ @player.id, friend.id ].max)
      Game::Holding.create!(player_id: friend.id, card_season_id: depths, quantity: 1)
      Game::ProposeTrade.new.call(player: @player, recipient: friend, offer: { portal => 1 }, request: { depths => 1 }).value!
    end
    sign_in settings_path(locale: :fr)

    within("[role=group][aria-labelledby=settings-visibility]") { click_on "Privé" }
    within("dialog#private-dialog[open]") do
      assert_text "Passer en privé annule vos 2 échanges en cours."
      click_on "Annuler"
    end
    assert_no_selector "dialog#private-dialog[open]"
    assert_equal "public", @player.reload.visibility

    within("[role=group][aria-labelledby=settings-visibility]") { click_on "Privé" }
    within("dialog#private-dialog[open]") { click_on "Passer en privé" }
    assert_selector "button[name=visibility][aria-pressed=true]", text: "PRIVÉ"
    assert_equal "private", @player.reload.visibility
    assert_equal [ "cancelled" ], Game::Trade.distinct.pluck(:status)
    assert_equal 0, Game::Holding.find_by!(player_id: @player.id, card_season_id: portal).reserved
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

  test "a player picks reduced motion on the settings screen, and the switch follows on every page, signed in and out" do
    sign_in
    find(".top-bar .player-chip__button").click
    find(".profile-band__settings").click
    assert_selector "h1", text: "SETTINGS"
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

  test "the support row opens the donation page in a new tab, and the closing link opens the legal page in the player's locale" do
    sign_in(settings_path(locale: :fr))

    support = find(".settings-row", text: /SOUTENIR/).find("a")
    assert_equal [ "https://buymeacoffee.com/theiereman", "_blank" ], [ support[:href], support[:target] ]
    assert_includes support[:rel].split, "noopener"

    find(".settings__list > li:last-child a", text: /mentions légales/i).click

    assert_current_path "/fr/legal"
    assert_selector "h1#legal-heading", text: /mentions légales/i
    assert_selector ".legal__ownership", text: "Toutes les illustrations appartiennent aux éditeurs des jeux et à leurs artistes, que nous respectons."
  end

  test "a player without Steam links it from the sign-ins row, stays signed in and finds Steam listed" do
    sign_in
    Accounts::Identity.where(player_id: @player.id, provider: "steam").delete_all
    @player.update_columns(steam_id: nil)
    visit settings_path(locale: :en)
    assert_no_selector "ul.sign-in-methods li", text: /steam/i
    mock_steam_sign_in("76561197960287930")

    click_on "Link Steam"

    assert_selector ".toast", text: /steam is linked to your account/i
    assert_current_path settings_path(locale: :en)
    assert_selector "ul.sign-in-methods li", text: /steam/i
    assert_no_button "Link Steam"
    assert_signed_in
    assert_equal [ @player.id ], Accounts::Identity.where(provider: "steam", uid: "76561197960287930").pluck(:player_id)
  end

  test "sign-out from the settings screen lands on the landing" do
    sign_in(settings_path(locale: :en))

    click_on "Sign out"

    assert_signed_out
    assert_selector ".landing-hero"
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

  def box(selector)
    page.evaluate_script("(() => { const r = document.querySelector(#{selector.to_json}).getBoundingClientRect(); return { left: r.left, right: r.right, top: r.top, bottom: r.bottom, width: r.width } })()").transform_keys(&:to_sym)
  end

  def no_horizontal_scroll?
    page.evaluate_script("document.documentElement.scrollWidth <= document.documentElement.clientWidth")
  end

  def assert_every_setting_shown
    assert_selector ".settings__main .settings-row", count: 9
    assert_selector ".settings__main .segmented[aria-labelledby=settings-language]"
    assert_selector ".settings__main .segmented[aria-labelledby=settings-visibility]"
    assert_selector ".settings__main .segmented[aria-labelledby=settings-motion]"
    assert_selector ".settings__main .settings-row a.button--link", text: /legal notice/i
  end

  test "on a desktop the settings take one column, reached from the own profile" do
    sign_in
    find(".player-chip__button").click
    find(".profile-band__settings").click
    assert_selector "h1", text: "SETTINGS"

    [ 1400, 1000 ].each do |width|
      resize_to(width, width)
      assert_no_selector ".settings-summary"
      assert_every_setting_shown
      assert no_horizontal_scroll?, "no sideways scroll at #{width}px"
      take_screenshot
    end
  end

  test "on a phone the settings stay one column with no sideways scroll" do
    resize_to(390, 844)
    sign_in settings_path(locale: :en)

    assert_every_setting_shown
    assert no_horizontal_scroll?
    take_screenshot
  end

  test "on a phone, the avatar leads to the own profile, its gear to the settings, and the contextual back to the profile" do
    page.driver.browser.manage.window.resize_to(390, 844)
    sign_in

    find(".top-bar .player-chip__button").click
    assert_current_path brother_path(locale: :en, token: @player.token)
    find(".profile-band__settings").click

    assert_selector "h1", text: "SETTINGS"
    assert_no_selector ".tab-bar__tab[aria-current=page]"
    within(".top-bar") { click_on "Profile" }
    assert_current_path brother_path(locale: :en, token: @player.token)
  end
end

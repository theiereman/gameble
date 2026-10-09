require "test_helper"
require_relative "../support/game_packs"

# The shell around every page (story 8.1; AD-28; DESIGN.md, Chrome;
# EXPERIENCE.md, Toast): the head's metas and font preloads, the top bar for
# a visitor and for a player, the phone tab bar, the atmosphere, the toasts
# that replace the flash, and the back-office variant.
class ShellTest < ActionDispatch::IntegrationTest
  include GamePacks

  setup do
    OmniAuth.config.test_mode = true
  end

  teardown do
    OmniAuth.config.mock_auth.delete(:steam)
    OmniAuth.config.test_mode = false
  end

  def sign_in(player, origin: "/en")
    OmniAuth.config.mock_auth[:steam] = OmniAuth::AuthHash.new(provider: "steam", uid: "https://steamcommunity.com/openid/id/#{player.steam_id}")
    post "/auth/steam", params: { origin: origin }
    follow_redirect!
    assert_equal player.id, session[:player_id]
  end

  def hold(player, card_season, quantity)
    Game::Holding.create!(player_id: player.id, card_season_id: catalog_card_seasons(card_season).id, quantity:)
  end

  test "the head: title, viewport for the notch, theme colour, view transitions, the three latin fonts preloaded" do
    get home_path(locale: :fr)

    assert_select "title", "gameble"
    assert_select "meta[name=viewport][content=?]", "width=device-width,initial-scale=1,viewport-fit=cover"
    assert_select "meta[name=theme-color][content=?]", "#171a21"
    assert_select "meta[name=view-transition][content=same-origin]"
    preloads = css_select("link[rel=preload][as=font][type='font/woff2'][crossorigin]").map { it["href"] }
    assert_equal 3, preloads.size
    %w[space-mono-latin-400 space-mono-latin-700 vt323-latin-400].each do |font|
      assert(preloads.any? { it.include?("/#{font}-normal") }, "#{font} should be preloaded")
    end
    assert_no_match(/fonts\.googleapis|fonts\.gstatic/, response.body)
  end

  test "no style attribute anywhere in the shell" do
    player = accounts_players(:player)
    create_pack(player, available_at: 5.minutes.from_now)
    sign_in(player)

    get library_path(locale: :en)

    assert_select "[style]", false
  end

  test "a visitor on the hub: the logo and the official Steam image as a POST form back to this page" do
    get home_path(locale: :fr)

    assert_select "body > header.top-bar" do
      assert_select ".top-bar__start .top-bar__brand svg.pixel-icon.top-bar__logo"
      assert_select ".top-bar__start .top-bar__brand .top-bar__name", "gameble"
      assert_select ".top-bar__start a.button", false
      assert_select ".top-bar__end form.steam-sign-in[action='/auth/steam'][method=post][data-turbo=false]" do
        assert_select "input[type=hidden][name=origin][value='/fr']"
        assert_select "button.steam-sign-in__button img[alt=?]", "Se connecter via Steam (ouvre Steam)"
      end
      assert_select ".rarity-counter, .packs-chip, .player-chip", false
    end
  end

  test "a visitor elsewhere signs in back to that page" do
    get library_path(locale: :en)

    assert_select ".top-bar__end form.steam-sign-in input[name=origin][value='/en/library']"
  end

  test "a player elsewhere: the back button to the bridge, the rarity counter, the packs chip and the player chip" do
    player = accounts_players(:player)
    hold(player, :common_card_one, 3)
    hold(player, :portal_one, 1)
    3.times { create_pack(player) }
    create_pack(player, available_at: 125.seconds.from_now)
    sign_in(player)

    get card_path(locale: :en, slug: "portal")

    assert_select ".top-bar__start > a.button.button--secondary.button--small[href='/en']" do
      assert_select "svg.pixel-icon.button__icon[aria-hidden=true]"
      assert_select ".button__label", "Bridge"
    end
    assert_select ".top-bar__brand", false

    assert_select ".rarity-counter button.rarity-counter__button[type=button][popovertarget=rarity-legend]" do
      assert_select ".rarity-counter__item", 5
      assert_select ".rarity-counter__item svg.pixel-icon", 5
      assert_equal %w[3 0 0 1 0], css_select(".rarity-counter__count").map { it.text.strip }
      assert_select ".visually-hidden", /Rarities/
    end
    assert_select "#rarity-legend[popover]" do
      assert_select ".shell-popover__title", "Rarities"
      assert_select "li.rarity-legend__row", 5
      assert_equal [ "Common", "Uncommon", "Rare", "Epic", "Legendary" ], css_select(".rarity-legend__name").map(&:text)
      assert_equal %w[3 0 0 1 0], css_select(".rarity-legend__count").map(&:text)
    end

    assert_select ".top-bar__end a.packs-chip[href='/en/booster'][data-turbo-prefetch=false]" do
      assert_select "svg.pixel-icon.packs-chip__icon"
      assert_select ".packs-chip__count", "3"
      assert_select ".packs-chip__label", "Boosters"
      assert_select ".packs-chip__next[data-controller=countdown][data-countdown-refresh-value=false]" do |next_in|
        assert_in_delta 125, next_in.first["data-countdown-seconds-value"].to_i, 2
      end
      assert_select ".packs-chip__next [aria-hidden=true]", /\+1 in/
      assert_select ".packs-chip__next .visually-hidden", /\ANext booster at \d\d:\d\d \(UTC\)\z/
    end
    assert_select ".packs-chip a, p.packs-chip", false

    assert_select ".player-chip button.player-chip__button[popovertarget=player-menu]" do
      assert_select "svg.pixel-icon.player-chip__avatar"
      assert_select ".player-chip__name", "Player"
      assert_select ".player-chip__dot[aria-hidden=true]"
    end
    assert_select "nav#player-menu[popover][aria-label=?]", "Player menu" do
      assert_select "a.player-menu__item[href=?]", "/en/brothers/#{player.token}", text: "My public profile"
      assert_select "a[href='/en/back-office']", false
      assert_select "form[action=?] input[name=_method][value=delete]", "/session?locale=en"
      assert_select "form button.player-menu__item", "Sign out"
    end
    assert_select ".top-bar form[action='/auth/steam']", false
  end

  test "a full reserve shows instead of the countdown" do
    player = accounts_players(:player)
    Game::Pack::BANK_SIZE.times { create_pack(player) }
    sign_in(player)

    get home_path(locale: :fr)

    assert_select ".packs-chip__count", Game::Pack::BANK_SIZE.to_s
    assert_select ".packs-chip__next--full", "Réserve pleine"
    assert_select ".packs-chip [data-controller=countdown]", false
  end

  test "no published season: the rarity counter shows zeros" do
    player = accounts_players(:player)
    hold(player, :common_card_one, 3)
    catalog_seasons(:one).update_columns(status: "draft", published_at: nil)
    sign_in(player)

    get library_path(locale: :en)

    assert_equal %w[0 0 0 0 0], css_select(".rarity-counter__count").map { it.text.strip }
  end

  test "staff find the back-office in the player menu" do
    sign_in(accounts_players(:moderator))

    get library_path(locale: :fr)

    assert_select "#player-menu a.player-menu__item[href='/fr/back-office']", "Back-office"
  end

  test "the phone tab bar: five tabs, the screens as links, trades a sign-in for a visitor, locked during an opening" do
    get library_path(locale: :fr)

    assert_select "nav.tab-bar[aria-label=?] ul.tab-bar__list > li.tab-bar__item", "Navigation principale", 5
    assert_equal [ "Pont", "Booster", "Collection", "Échanges", "Plus" ], css_select(".tab-bar__label").map(&:text)
    assert_select "a.tab-bar__tab[href='/fr']:not([aria-current])", /Pont/
    assert_select "a.tab-bar__tab[href='/fr/booster']:not([aria-current])", /Booster/
    assert_select "a.tab-bar__tab[href='/fr/library'][aria-current=page]", /Collection/
    assert_select "a.tab-bar__tab[href='/fr/more']:not([aria-current])", /Plus/
    assert_select "span.tab-bar__tab[aria-disabled=true]", 0
    assert_select "button.tab-bar__tab[aria-haspopup=dialog][data-dialog-opener-dialog-value=sign-in-panel]", /Échanges/
    assert_select "nav.tab-bar[data-controller=navigation-lock]"
    assert_select ".top-bar__start[data-controller=navigation-lock]"
    assert_select ".tab-bar__tab svg.pixel-icon.tab-bar__icon", 5

    get home_path(locale: :fr)
    assert_select "a.tab-bar__tab[href='/fr'][aria-current=page]"
  end

  test "the atmosphere: permanent, hidden, under the page" do
    get home_path(locale: :en)

    assert_select "body > #atmosphere.atmosphere[data-turbo-permanent][aria-hidden=true]:first-child" do
      assert_select ".atmosphere__stars[data-controller=starfield]"
      assert_select ".atmosphere__twinkle > i", 12
      assert_select ".atmosphere__scanlines"
      assert_select ".atmosphere__vignette"
    end
    assert_select "body > header.top-bar + #live-ticker.ticker + main#main.main"
    assert_select "body:not(.is-back-office)"
  end

  test "the flash shows as toasts in a polite live region, with the template for later ones" do
    sign_in(accounts_players(:player))
    follow_redirect!

    assert_select "body > .toasts[role=status][aria-live=polite][data-controller=toast]" do
      assert_select "> .toast.toast--notice[data-turbo-temporary]", 1
      assert_select "> .toast .toast__message", flash[:notice]
      assert_select "> .toast button.toast__close[aria-label=Close]"
      assert_select "> template[data-toast-target=template]"
    end

    get home_path(locale: :en)
    assert_select ".toasts > .toast", 0
  end

  test "an alert is an alert toast" do
    get settings_path(locale: :en)
    follow_redirect!

    assert_select ".toasts > .toast.toast--alert .toast__message", I18n.t("authorization.sign_in_required", locale: :en)
  end

  test "the back-office: the tokens and the top bar's way back, no atmosphere and no tab bar" do
    sign_in(accounts_players(:administrator))

    get back_office_path(locale: :fr)

    assert_response :success
    assert_select "body.is-back-office"
    assert_select ".top-bar__start > a.button--secondary[href='/fr'] .button__label", "Pont"
    assert_select "#atmosphere, .atmosphere", false
    assert_select ".tab-bar", false
    assert_select ".rarity-counter, .packs-chip", false
    assert_select ".player-chip"
    assert_select "link[rel=stylesheet][href*='/application-']"
  end
end

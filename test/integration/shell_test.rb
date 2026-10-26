require "test_helper"
require_relative "../support/game_packs"
require_relative "../support/steam_sign_in"

# The shell around every page (story 8.1; AD-28; DESIGN.md, Chrome;
# EXPERIENCE.md, Toast): the head's metas and font preloads, the top bar for
# a visitor and for a player, the phone tab bar, the atmosphere, the toasts
# that replace the flash, and the back-office variant.
class ShellTest < ActionDispatch::IntegrationTest
  include GamePacks
  include SteamSignIn

  def hold(player, card_season, quantity)
    Game::Holding.create!(player_id: player.id, card_season_id: catalog_card_seasons(card_season).id, quantity:)
  end

  def assert_wordmark_sweeps_on_hover(brand = "a.top-bar__home")
    sweep = "#{brand}[data-controller=wordmark-shine]"
    assert_select "#{sweep}[data-action=?]", "pointerenter->wordmark-shine#sweep animationend->wordmark-shine#end animationcancel->wordmark-shine#end"
    assert_select "#{sweep} svg.top-bar__wordmark g.wordmark-sweep__frames"
  end

  test "the head: title, the gold G favicon, viewport for the notch, theme colour, view transitions, the three latin fonts preloaded" do
    sign_in(accounts_players(:player))
    get home_path(locale: :fr)

    assert_select "title", "Gameble"
    assert_select "link[rel=icon][type='image/svg+xml'][href*='/favicon-'][href$='.svg']"
    assert_select "link[rel=icon][type='image/png'][sizes='180x180'][href*='/favicon-'][href$='.png']"
    assert_select "link[rel=apple-touch-icon][href*='/favicon-'][href$='.png']"
    assert_select "meta[name=viewport][content=?]", "width=device-width,initial-scale=1,viewport-fit=cover"
    assert_select "meta[name=theme-color][content=?]", "#171a21"
    assert_select "meta[name=view-transition][content=same-origin]"
    preloads = css_select("link[rel=preload][as=font][type='font/woff2'][crossorigin]").map { it["href"] }
    assert_equal 3, preloads.size
    %w[jetbrains-mono-latin-400 jetbrains-mono-latin-700 vt323-latin-400].each do |font|
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

  test "a visitor on the landing: the wordmark and the official Steam image as a POST form back to this page" do
    get home_path(locale: :fr)

    assert_select "body > header.top-bar:not([data-screen-label])" do
      assert_select ".top-bar__start p.top-bar__brand svg.pixel-icon.top-bar__wordmark"
      assert_select ".top-bar__start .top-bar__brand .top-bar__name", "Gameble"
      assert_select ".top-bar__start a", false
      assert_select ".top-bar__end form.steam-sign-in[action='/auth/steam'][method=post][data-turbo=false]" do
        assert_select "input[type=hidden][name=origin][value='/fr']"
        assert_select "button.steam-sign-in__button img[alt=?]", "Se connecter via Steam (ouvre Steam)"
      end
      assert_select ".rarity-counter, .packs-chip, .player-chip", false
    end
  end

  test "no open page carries a sign-in panel or a button opening one" do
    profile = brother_path(locale: :fr, token: accounts_players(:player).token)
    [ home_path(locale: :fr), library_cards_path(locale: :fr), how_it_works_path(locale: :fr), legal_path(locale: :fr), profile ].each do |path|
      get path

      assert_response :success, path
      assert_select "dialog#sign-in-panel, [data-dialog-opener-dialog-value=sign-in-panel], .sign-in-panel__acceptance", false, path
    end
  end

  test "a visitor's wordmark, phone brand and phone back lead to the landing; a player's to the hub" do
    get library_cards_path(locale: :fr)

    assert_select ".top-bar__start > a.top-bar__brand.top-bar__home[href='/fr'][aria-label=?]", "Gameble, page d'accueil"
    assert_select ".top-bar__start > a.button.top-bar__bridge[href='/fr'] .button__label", "Accueil"
    invite = invite_link_path(locale: :en, token: accounts_players(:moderator).token)
    get invite
    assert_select ".top-bar__start > a.top-bar__home[href='/en'][aria-label=?]", "Gameble, home page"
    assert_select ".top-bar__start > a.top-bar__brand.top-bar__phone-brand[href='/en'][aria-label=?]", "Gameble, home page"

    sign_in(accounts_players(:player))
    get invite
    assert_select ".top-bar__start > a.top-bar__home[href='/en'][aria-label=?]", "Gameble, command bridge"
    assert_select ".top-bar__start > p.top-bar__brand.top-bar__phone-brand"
  end

  test "a visitor's tab bar has two links, the landing and every card, none disabled" do
    get library_cards_path(locale: :fr)

    assert_select "nav.tab-bar ul.tab-bar__list.tab-bar__list--visitor > li.tab-bar__item > a.tab-bar__tab", 2
    assert_equal [ "Accueil", "Toutes les cartes" ], css_select(".tab-bar__label").map(&:text)
    assert_select "a.tab-bar__tab[href='/fr']:not([aria-current])", /Accueil/
    assert_select "a.tab-bar__tab[href='/fr/library/cards'][aria-current=page]", /Toutes les cartes/
    assert_select ".tab-bar__tab svg.pixel-icon.tab-bar__icon", 2
    assert_select ".tab-bar button, .tab-bar [disabled], .tab-bar [aria-disabled]", false
    assert_select "#tab-trades-badge", false
  end

  test "a visitor's every cards tab stays current on a card's detail; no tab is current on a profile or the feed" do
    get library_cards_path(locale: :fr)
    get css_select("main a[href*='/fr/cards/']").first["href"]
    assert_response :success
    assert_select "a.tab-bar__tab[href='/fr/library/cards'][aria-current=page]"

    get card_season_path(locale: :fr, slug: "portal", number: 1, set_kind: "studio", set_key: "valve")
    assert_select "a.tab-bar__tab[href='/fr/library/cards'][aria-current=page]"

    get brother_path(locale: :fr, token: accounts_players(:player).token)
    assert_select "a.tab-bar__tab", 2
    assert_select "a.tab-bar__tab[aria-current]", false

    get feed_path(locale: :fr)
    assert_select "a.tab-bar__tab", 2
    assert_select "a.tab-bar__tab[aria-current]", false
  end

  test "a signed-in player has no sign-in panel" do
    sign_in(accounts_players(:player))

    get home_path(locale: :fr)

    assert_response :success
    assert_select "dialog#sign-in-panel", false
    assert_select ".sign-in-panel__acceptance", false
  end

  test "a visitor elsewhere signs in back to that page" do
    get library_cards_path(locale: :en)

    assert_select ".top-bar__end form.steam-sign-in input[name=origin][value='/en/library/cards']"
  end

  test "a player elsewhere: the back button to the bridge, the rarity counter, the packs chip and the player chip" do
    player = accounts_players(:player)
    hold(player, :common_card_one, 3)
    hold(player, :portal_one, 1)
    3.times { create_pack(player) }
    create_pack(player, available_at: 125.seconds.from_now)
    sign_in(player)

    get card_path(locale: :en, slug: "portal")

    assert_select "header.top-bar[data-screen-label=Card]"
    assert_select ".top-bar__start > a.top-bar__brand.top-bar__home:first-child[href='/en'][aria-label=?]", "Gameble, command bridge" do
      assert_select "svg.pixel-icon.top-bar__wordmark[aria-hidden=true]"
      assert_select ".top-bar__name", "Gameble"
    end
    assert_wordmark_sweeps_on_hover
    assert_select ".top-bar__home + .top-bar__divider[aria-hidden=true]"
    assert_select ".top-bar__start > a.button.button--secondary.button--small.top-bar__bridge[href='/en']" do
      assert_select "svg.pixel-icon.button__icon[aria-hidden=true]"
      assert_select ".button__label", "Bridge"
    end
    assert_select ".top-bar__start > a.top-bar__previous[hidden][data-controller=previous-screen]:not([href])" do
      assert_select ".visually-hidden", "Back:"
      assert_select ".button__label[data-previous-screen-target=label]", ""
    end

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
      assert_select ".packs-chip__label", "Capsules"
      assert_select ".packs-chip__next[data-controller=countdown][data-countdown-refresh-value=false]" do |next_in|
        assert_in_delta 125, next_in.first["data-countdown-seconds-value"].to_i, 2
      end
      assert_select ".packs-chip__next [aria-hidden=true]", /\+1 in/
      assert_select ".packs-chip__next .visually-hidden", /\ANext capsule: \d{4}-\d\d-\d\d \d\d:\d\d UTC\z/
      assert_select ".packs-chip__next .visually-hidden time[data-controller=local-time][data-local-time-style-value=datetime][datetime]"
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

  test "a screen without a back button: the wordmark links to the hub on a desktop, the plain brand on a phone, each sweeping on hover" do
    sign_in(accounts_players(:player))

    get more_path(locale: :en)

    assert_select ".top-bar__start > a.top-bar__brand.top-bar__home[href='/en'][aria-label=?]", "Gameble, command bridge" do
      assert_select "svg.pixel-icon.top-bar__wordmark"
      assert_select ".top-bar__name", "Gameble"
    end
    assert_select ".top-bar__start > p.top-bar__brand.top-bar__phone-brand .top-bar__name", "Gameble"
    assert_wordmark_sweeps_on_hover
    assert_wordmark_sweeps_on_hover ".top-bar__start > p.top-bar__phone-brand"

    get home_path(locale: :en)

    assert_select ".top-bar__start a", false
    assert_select ".top-bar__start > p.top-bar__brand:not(.top-bar__phone-brand)"
    assert_wordmark_sweeps_on_hover ".top-bar__start > p.top-bar__brand"
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

  test "a new season's publication leaves the rarity counter as it stood: every edition counts" do
    player = accounts_players(:player)
    hold(player, :common_card_one, 3)
    newer = Catalog::Season.create!(status: :draft, number: Catalog::Season.next_number)
    newer.update!(status: :published, published_at: Time.current)
    sign_in(player)

    get more_path(locale: :en)

    assert_equal %w[3 0 0 0 0], css_select(".rarity-counter__count").map { it.text.strip }
  end

  test "staff find the back-office in the player menu" do
    sign_in(accounts_players(:moderator))

    get library_path(locale: :fr)

    assert_select "#player-menu a.player-menu__item[href='/fr/back-office']", "Back-office"
  end

  test "the phone tab bar: five tabs, the screens as links, locked during an opening" do
    sign_in(accounts_players(:player))
    get library_path(locale: :fr)

    assert_select "nav.tab-bar[aria-label=?] ul.tab-bar__list > li.tab-bar__item", "Navigation principale", 5
    assert_equal [ "Pont", "Capsule", "Collection", "Échanges", "Plus" ], css_select(".tab-bar__label").map(&:text)
    assert_select "a.tab-bar__tab[href='/fr']:not([aria-current])", /Pont/
    assert_select "a.tab-bar__tab[href='/fr/booster']:not([aria-current])", /Capsule/
    assert_select "a.tab-bar__tab[href='/fr/library'][aria-current=page]", /Collection/
    assert_select "a.tab-bar__tab[href='/fr/more']:not([aria-current])", /Plus/
    assert_select "a.tab-bar__tab[href='/fr/trades']:not([aria-current])", /Échanges/
    assert_select "span.tab-bar__tab[aria-disabled=true], button.tab-bar__tab, .tab-bar__list--visitor", 0
    assert_select "nav.tab-bar[data-controller=navigation-lock]"
    assert_select ".top-bar__start[data-controller=navigation-lock]"
    assert_select ".tab-bar__tab svg.pixel-icon.tab-bar__icon", 5

    get home_path(locale: :fr)
    assert_select "a.tab-bar__tab[href='/fr'][aria-current=page]"
  end

  test "the atmosphere: permanent, hidden, under the page" do
    sign_in(accounts_players(:player))
    get home_path(locale: :en)

    assert_select "body > #atmosphere.atmosphere[data-turbo-permanent][aria-hidden=true]:first-child" do
      assert_select ".atmosphere__stars[data-controller=starfield]"
      assert_select ".atmosphere__twinkle > i", 12
      assert_select ".atmosphere__scanlines"
      assert_select ".atmosphere__vignette"
    end
    assert_select "body > header.top-bar + main#main.main + #live-ticker.ticker"
    assert_select "body:not(.is-back-office)"
  end

  test "the LIVE ticker runs along the bottom of the hub and of no other screen" do
    get library_cards_path(locale: :en)
    assert_select ".ticker", 0

    sign_in(accounts_players(:player))
    get home_path(locale: :en)
    assert_select "body > main#main + #live-ticker.ticker", 1
    [ library_path(locale: :en), feed_path(locale: :en), trades_path(locale: :en), friends_path(locale: :en),
      settings_path(locale: :en), more_path(locale: :en) ].each do |path|
      get path
      assert_response :success
      assert_select ".ticker", 0, "#{path} should carry no ticker"
    end
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
    get auth_failure_path(message: "invalid_credentials", origin: "/en")
    follow_redirect!

    assert_select ".toasts > .toast.toast--alert .toast__message", I18n.t("errors.steam.sign_in_failed", locale: :en)
  end

  test "the back-office: the tokens and the top bar's way back, no atmosphere and no tab bar" do
    sign_in(accounts_players(:administrator))

    get back_office_path(locale: :fr)

    assert_response :success
    assert_select "body.is-back-office"
    assert_select ".top-bar__start > a.button--secondary[href='/fr'] .button__label", "Pont"
    assert_select ".top-bar__start > a.top-bar__home[href='/fr'][aria-label=?]", "Gameble, pont de commandement"
    assert_select ".top-bar__previous .visually-hidden", "Retour :"
    assert_select "header.top-bar[data-screen-label=Back-office]"
    assert_select "#atmosphere, .atmosphere", false
    assert_select ".tab-bar", false
    assert_select ".rarity-counter, .packs-chip", false
    assert_select ".player-chip"
    assert_select "link[rel=stylesheet][href*='/application-']"
  end

  test "the back-office keeps the legal page beside the version" do
    sign_in(accounts_players(:administrator))

    get back_office_path(locale: :fr)

    assert_select "body > .app-version a.app-version__legal[href=?]", "/fr/legal", "Mentions légales"
  end

  test "the public card page keeps the legal page beside the version" do
    get card_path(locale: :en, slug: "portal")

    assert_select "body.is-public-page"
    assert_select "body > .app-version a.app-version__legal[href=?]", "/en/legal", "Legal notice"
  end
end

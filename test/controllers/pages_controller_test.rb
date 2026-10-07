require "test_helper"
require_relative "../support/game_packs"

# The hub, "Pont de commandement" (story 8.2; DESIGN.md: Menu item, Showcase,
# Daily booster panel, Set progress row, Signed-out hub, Sign-in panel), as
# the server renders it for a player and for a visitor.
class PagesControllerTest < ActionDispatch::IntegrationTest
  include GamePacks

  PLAYER_HUB_QUERIES = 13
  VISITOR_HUB_QUERIES = 4

  setup do
    Game::DrawPool.reset!
    OmniAuth.config.test_mode = true
    @player = accounts_players(:player)
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

  def epic_name(locale)
    I18n.t("catalog.rarity.#{Catalog::Rarity::TIERS.fetch(4)}", locale:)
  end

  def menu_items
    css_select(".hub-menu .menu-item")
  end

  test "the French hub renders in French with the top bar above the main region" do
    get home_path(locale: :fr)

    assert_response :success
    assert_select "html[lang=fr]"
    assert_select "title", "gameble"
    assert_select "body > header.top-bar + main#main"
    assert_select "nav.tab-bar[aria-label=?]", "Navigation principale"
    assert_select "main h1.hub__title[tabindex='-1']", "Pont de commandement"
    assert_select "main .hub__kicker .hub__subtitle", false
  end

  test "the English hub renders in English and loads its Vite assets" do
    get home_path(locale: :en)

    assert_response :success
    assert_select "html[lang=en]"
    assert_select "main h1", "Command bridge"
    assert_select "script[type=module][src^='/vite-test/assets/application-'][src$='.js']"
    assert_select "link[rel=stylesheet][href^='/vite-test/assets/application-'][href$='.css']"
  end

  test "a player's hub: the menu, the latest notable pull, the daily panel and the set progress" do
    create_pack(@player, cards: fixture_tier_ids.first(4) + fixture_tier_ids.first(1), opened_at: 1.hour.ago)
    Game::Holding.create!(player_id: @player.id, card_season_id: catalog_card_seasons(:portal_one).id, quantity: 2)
    3.times { create_pack(@player) }
    sign_in(@player)

    get home_path(locale: :fr)

    assert_response :success
    assert_select ".hub[data-controller=hub-menu]"
    assert_select "nav.hub-menu[aria-label=?] ol.hub-menu__list > li", "Menu du pont", count: 6
    assert_equal %w[1 2 3 4 5 6], menu_items.map { it["aria-keyshortcuts"] }
    assert_equal %w[01 02 03 04 05 06], css_select(".hub-menu .menu-item__number").map(&:text)

    # 01: the booster screen, its reserve in a lime badge.
    assert_select ".hub-menu a.menu-item[href='/fr/booster'][data-hub-menu-target=item][data-turbo-prefetch=false]" do
      assert_select ".menu-item__label", "Ouvrir un booster"
      assert_select ".menu-item__badge[aria-hidden=true]", "3"
      assert_select ".visually-hidden", "3 boosters en réserve"
      assert_select "svg.menu-item__arrow"
    end
    # 02: the collection, unique cards owned out of the season's.
    assert_select ".hub-menu a.menu-item[href='/fr/library'][aria-keyshortcuts='2']" do
      assert_select ".menu-item__label", "Collection"
      assert_select ".menu-item__meta", "1/5"
      assert_select ".visually-hidden", "1 carte unique sur 5"
    end
    # 03 to 06: no screen yet.
    disabled = css_select(".hub-menu span.menu-item[aria-disabled=true]")
    assert_equal [ "Échanges", "Fil d'activité", "Succès" ], disabled.map { it.at_css(".menu-item__label").text }
    assert disabled.all? { it.at_css(".visually-hidden").text == "bientôt disponible" }

    # The showcase: the tier 4 card of the pack, its rarity and its page.
    assert_select ".hub-showcase:not(.hub-showcase--empty)" do
      assert_select ".hub-showcase__kicker", "Dernière obtention"
      assert_select ".card.card--xl", 1
      assert_select "h2.hub-showcase__name", "Portal"
      assert_select ".hub-showcase__rarity.hub-showcase__rarity--4 svg.pixel-icon"
      assert_select ".hub-showcase__rarity span", epic_name(:fr)
      assert_select "a.button.button--secondary[href='/fr/cards/portal']", "Voir la fiche"
    end

    # The daily panel, its button the view's one primary.
    assert_select "section.daily-booster.panel--quiet[aria-labelledby=daily-booster-title]" do
      assert_select "h2#daily-booster-title", "Booster quotidien"
      assert_select ".daily-booster__state--ready", "Prêt"
      assert_select ".daily-booster__text", "Un booster offert chaque jour. Il rejoint votre réserve."
      assert_select "form[action='/fr/daily-bonus'][method=post] button.button--primary.button--small", "Récupérer"
    end
    assert_select "main .button--primary", 1

    # The set progress: the season's one set, owned out of its size.
    assert_select ".hub-sets h2", "Progression des sets"
    assert_select ".hub-sets a.set-row[href='/fr/library/publisher/valve']" do
      assert_select ".set-row__name", "Valve"
      assert_select ".set-row__count", "1/1"
      assert_select ".visually-hidden", "1 carte possédée sur 1"
      assert_select "progress.set-row__bar[value='1'][max='1'][aria-hidden=true]"
    end
    assert_select ".hub-sets a.button--link[href='/fr/library']", "Tout voir"

    # A player has no sign-in panel; the page carries no inline style.
    assert_select "#sign-in-panel", false
    assert_select "[style]", false
  end

  test "a player whose packs hold no tier 4 card sees the empty showcase, its primary opening a booster" do
    create_pack(@player, cards: Array.new(5, fixture_tier_ids.first), opened_at: 1.hour.ago)
    create_pack(@player)
    sign_in(@player)

    get home_path(locale: :en)

    assert_select ".hub-showcase.hub-showcase--empty" do
      assert_select ".hub-showcase__kicker", false
      assert_select ".hub-showcase__frame[aria-hidden=true] .hub-showcase__outline svg.hub-showcase__logo"
      assert_select "h2.hub-showcase__name", "Open your first booster"
      assert_select ".hub-showcase__line", "Your finest card will show here."
      assert_select "a.button.button--primary[href='/en/booster']", "Open a booster"
    end
    # One lime action: the daily panel's button turns secondary.
    assert_select ".daily-booster form button.button--secondary.button--small", "Collect"
    assert_select "main .button--primary", 1
  end

  test "an empty reserve greys menu 01's badge and disables the empty showcase's button, saying why" do
    sign_in(@player)

    get home_path(locale: :en)

    assert_select ".hub-menu a.menu-item[href='/en/booster'][aria-keyshortcuts='1']:not([aria-disabled])" do
      assert_select ".menu-item__badge.menu-item__badge--zero[aria-hidden=true]", "0"
      assert_select ".visually-hidden", "Reserve empty"
    end
    assert_select ".hub-menu form[action='/en/packs']", false
    assert_select ".hub-showcase--empty button.button[type=button][disabled]", "Open a booster"
    assert_select ".hub-showcase--empty .hub-showcase__reason", "Reserve empty"
    assert_select "main form[action='/en/packs']", false
  end

  test "on the hub the packs chip's countdown refreshes the page; elsewhere it stops" do
    create_pack(@player, available_at: 5.minutes.from_now)
    sign_in(@player)

    get home_path(locale: :en)
    assert_select ".top-bar .packs-chip__next[data-controller=countdown][data-countdown-refresh-value=true]"

    get card_path(locale: :en, slug: "portal")
    assert_select ".top-bar .packs-chip__next[data-controller=countdown][data-countdown-refresh-value=false]"
  end

  test "a full reserve: the daily panel says so in orange and its button is disabled" do
    10.times { create_pack(@player) }
    sign_in(@player)

    get home_path(locale: :fr)

    assert_select ".daily-booster" do
      assert_select ".daily-booster__state--full", "Réserve pleine"
      assert_select ".daily-booster__text", "Ouvrez un booster pour récupérer celui du jour."
      assert_select "button.button.button--small[type=button][disabled]", "Récupérer"
      assert_select "form", false
    end
  end

  test "once the day's booster is collected, the daily panel stays: collected, with the countdown to 00:00 UTC and its bar" do
    Game::CollectDailyBonus.new.call(player: @player).value!
    sign_in(@player)

    travel_to(Time.current.utc.change(hour: 22, min: 30, sec: 15)) do
      get home_path(locale: :en)

      assert_select ".daily-booster.daily-booster--collected" do
        assert_select ".daily-booster__state", "Collected"
        assert_select ".daily-booster__text", "A booster joins your reserve. The next one will be ready at midnight (UTC)."
        assert_select ".daily-booster__next[data-controller=countdown][data-countdown-seconds-value='5385'][data-countdown-hours-value=true]" do
          assert_select ".daily-booster__next-label", "Next in"
          assert_select ".daily-booster__clock[data-countdown-target=clock]", "01:29:45"
          assert_select "progress.daily-booster__bar[max='86400'][value='81015']"
          assert_select ".visually-hidden", "Next booster at midnight (UTC)"
        end
        assert_select "button, a.button, form", false
      end
    end
    assert_select ".hub-menu a.menu-item[href='/en/booster'] .menu-item__badge"
  end

  test "a visitor's hub: the menu opens the sign-in panel, an invitation replaces the showcase, no daily panel" do
    get home_path(locale: :en)

    assert_response :success
    assert_select "main h1", "Command bridge"
    assert_select ".hub-menu button.menu-item[type=button][aria-haspopup=dialog][aria-keyshortcuts='1']" do |items|
      item = items.sole
      assert_equal "dialog-opener", item["data-controller"]
      assert_equal "dialog-opener#open", item["data-action"]
      assert_equal "sign-in-panel", item["data-dialog-opener-dialog-value"]
      assert_select item, ".menu-item__label", "Open a booster"
      assert_select item, ".menu-item__badge", false
    end
    assert_select ".hub-menu a.menu-item[href='/en/library'] .menu-item__meta", "0/5"

    assert_select ".hub-invitation" do
      assert_select "h2.hub-invitation__title", "Your Steam games, as collectible cards."
      assert_select ".hub-showcase__line", "Open boosters, complete sets, trade with your friends."
      assert_select "button.button.button--primary[type=button][aria-haspopup=dialog][data-dialog-opener-dialog-value=sign-in-panel]", "Open my first boosters"
    end
    assert_select ".hub-showcase:not(.hub-invitation)", false
    assert_select ".daily-booster", false
    assert_select ".hub-sets a.set-row .set-row__count", "0/1"
    assert_select "main form[action='/auth/steam']", false
    assert_select "a[href='/en/back-office']", false
    assert_select ".top-bar__start a.button", false
  end

  test "a visitor gets the sign-in panel: its title, the official image focused first and the close button" do
    get home_path(locale: :fr)

    assert_select "body > dialog#sign-in-panel.modal[aria-labelledby=sign-in-panel-title][data-controller=dialog]" do
      assert_select ".panel.panel--brackets"
      assert_select "p#sign-in-panel-title", "Connectez-vous pour jouer"
      assert_select "button.modal__close[type=button][aria-label=Fermer][data-action='dialog#close'] svg.pixel-icon"
      assert_select "form.steam-sign-in[action='/auth/steam'] input[name=origin][value='/fr']"
      assert_select "button.steam-sign-in__button[autofocus] img[src*='sits_01']"
      assert_select "a", false
    end
  end

  test "every form posting to /auth/steam is the official Steam image" do
    get home_path(locale: :en)

    forms = css_select("form[action='/auth/steam']")
    assert_equal 2, forms.size, "the top bar's and the sign-in panel's"
    assert forms.all? { it.classes.include?("steam-sign-in") && it.at_css("button.steam-sign-in__button img[src*='sits_01']") }
    assert_select "a[href*='/auth/steam']", false
  end

  test "no published season: no set rows and no collection meta" do
    catalog_seasons(:one).update_columns(status: "draft", published_at: nil)

    get home_path(locale: :en)
    assert_select ".hub-sets", false
    assert_select ".hub-menu .menu-item__meta", false

    sign_in(@player)
    get home_path(locale: :en)
    assert_select ".hub-sets", false
    assert_select ".hub-menu .menu-item__meta", false
    assert_select ".daily-booster", false
    assert_select ".hub-showcase--empty"
  end

  def assert_hub_queries(count)
    ActiveRecord::Base.connection.clear_query_cache
    assert_queries_count(count) { get home_path(locale: :en) }
    assert_response :success
  end

  test "a hub load costs a fixed number of queries, however long the player's history" do
    create_pack(@player, cards: fixture_tier_ids, opened_at: 2.hours.ago)
    Game::Holding.create!(player_id: @player.id, card_season_id: catalog_card_seasons(:portal_one).id, quantity: 2)
    sign_in(@player)

    # Player lookup, published season, bank (count, next pack, daily claim),
    # showcase (pull, card view), collection (owned, total), sets (progress,
    # the started sets, the fill, which finds no other set here, so no sizes)
    # and the top bar's copies per tier.
    assert_hub_queries(PLAYER_HUB_QUERIES)
    assert_select ".hub-showcase .card"

    # Many more opened packs, the pull now behind the RECENT latest: only the
    # showcase's second query is added.
    common = Array.new(Game::Pack::SIZE, catalog_card_seasons(:common_card_one).id)
    (Game::NotablePull::RECENT + 10).times { |index| create_pack(@player, cards: common, opened_at: (index + 1).minutes.ago) }
    assert_hub_queries(PLAYER_HUB_QUERIES + 1)
    assert_select ".hub-showcase .card"

    delete session_path(locale: :en)
    # Published season, collection total, sets fill and its totals.
    assert_hub_queries(VISITOR_HUB_QUERIES)
  end

  test "sets and cards are addressed by kind, key and slug, never by database id" do
    create_pack(@player, opened_at: 1.hour.ago)
    sign_in(@player)

    get home_path(locale: :en)

    body = css_select("main").sole.to_html
    ids = [ catalog_card_seasons(:portal_one).id, catalog_sets(:valve_one).id, catalog_seasons(:one).id ].map(&:to_s)
    assert ids.none? { |id| body.match?(/["\/=]#{id}["\/&]/) }, "no database id in the hub"
  end

  test "a sign-in lands on the hub, asking it to focus the first menu item" do
    sign_in(@player, origin: "/fr/library")

    assert_redirected_to "/fr"
    follow_redirect!
    assert_equal "/fr", path
    assert_select ".hub[data-hub-menu-focus-first-value=true]"

    get home_path(locale: :fr)
    assert_select ".hub[data-hub-menu-focus-first-value=false]"
  end

  test "the sign-in panel is for visitors only, never in the back-office" do
    sign_in(accounts_players(:administrator))

    get back_office_path(locale: :en)
    assert_select "#sign-in-panel", false
    get home_path(locale: :en)
    assert_select "#sign-in-panel", false
  end

  [ :moderator, :administrator ].each do |role|
    test "a #{role} sees the back-office link in the player menu, in the current locale" do
      sign_in(accounts_players(role))

      get home_path(locale: :fr)

      assert_select "#player-menu a.player-menu__item[href='/fr/back-office']", "Back-office"
    end
  end

  test "signing out is a full page load from the player menu" do
    sign_in(@player)
    get home_path(locale: :en)

    assert_select "#player-menu form.player-menu__form[action^='/session'][data-turbo=false]"
  end

  test "an unknown locale segment answers not found" do
    get "/de"

    assert_response :not_found
  end

  test "the health check answers when the application boots" do
    get "/up"

    assert_response :success
  end

  test "an unknown path answers not found" do
    get "/nope"

    assert_response :not_found
  end
end

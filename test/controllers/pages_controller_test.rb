require "test_helper"
require_relative "../support/catalog_seeds"
require_relative "../support/game_packs"
require_relative "../support/game_sets"
require_relative "../support/game_trades"
require_relative "../support/steam_sign_in"

# The hub, "Pont de commandement", as the server renders it for a player
# and for a visitor.
class PagesControllerTest < ActionDispatch::IntegrationTest
  include CatalogSeeds
  include GamePacks
  include GameSets
  include GameTrades
  include SteamSignIn

  PLAYER_HUB_QUERIES = 19
  VISITOR_HUB_QUERIES = 7

  OWNERSHIP_NOTICE = "Toutes les illustrations appartiennent aux éditeurs des jeux et à leurs artistes, que nous respectons."

  setup do
    @player = accounts_players(:player)
    @legal = Rails.configuration.x.legal
  end

  teardown do
    Rails.configuration.x.legal = @legal
  end

  def configure_legal(contact_email: nil, host_name: nil, host_address: nil)
    Rails.configuration.x.legal = ActiveSupport::OrderedOptions.new.update(contact_email:, host_name:, host_address:)
  end

  def epic_name(locale)
    I18n.t("catalog.rarity.#{Catalog::Rarity::TIERS.fetch(4)}", locale:)
  end

  def hold(card_season_id, gained_at:)
    Game::Holding.create!(player_id: @player.id, card_season_id:, quantity: 1, last_gained_at: gained_at)
  end

  def trade_away_only_copy(card_season_id)
    Game::Holding.where(player_id: @player.id, card_season_id:).update_all(quantity: 0)
    conclude_trade(@player, accounts_players(:moderator), offer: { card_season_id => 1 }, request: { fixture_tier_ids.first => 1 })
  end

  def written_statements(&request)
    statements = []
    recorder = ->(*, payload) { statements << payload[:sql] if payload[:sql].match?(/\A\s*(INSERT|UPDATE|DELETE)\b/i) }
    ActiveSupport::Notifications.subscribed(recorder, "sql.active_record", &request)
    statements
  end

  def menu_items
    css_select(".hub-menu .menu-item")
  end

  test "the French hub renders in French with the top bar above the main region" do
    get home_path(locale: :fr)

    assert_response :success
    assert_select "html[lang=fr]"
    assert_select "title", "gameble"
    assert_select "body > header.top-bar + main#main + .ticker"
    assert_select "nav.tab-bar[aria-label=?]", "Navigation principale"
    assert_select "main h1.hub__title[tabindex='-1']", "Pont de commandement"
    assert_select "main .hub__kicker .hub__subtitle", false
    assert_select "body > div.app-version" do
      assert_select "p.app-version__tag[title=?]", "Version déployée", text: "Version déployée dev"
      assert_select "a.app-version__legal[href=?]", "/fr/legal", "Mentions légales"
    end
  end

  test "the English hub renders in English and loads its Vite assets" do
    get home_path(locale: :en)

    assert_response :success
    assert_select "html[lang=en]"
    assert_select "main h1", "Command bridge"
    assert_select "script[type=module][src^='/vite-test/assets/application-'][src$='.js']"
    assert_select "link[rel=stylesheet][href^='/vite-test/assets/application-'][href$='.css']"
  end

  test "the showcase's line names the card's main theme as its genre, and leaves out a missing number" do
    hold(catalog_card_seasons(:portal_one).id, gained_at: 1.hour.ago)
    Catalog::CardSeason.where(id: catalog_card_seasons(:portal_one).id).update_all(main_theme: "puzzle")
    sign_in(@player)

    get home_path(locale: :fr)
    assert_select ".hub-showcase__rarity span", "#{epic_name(:fr)} · Réflexion · S1 · #4"

    catalog_card_seasons(:portal_one).update_columns(number: nil)
    get home_path(locale: :en)
    assert_select ".hub-showcase__rarity span", "#{epic_name(:en)} · Puzzle"
  end

  test "a showcased card traded away gives way to the previous one held, still with Repost, and the hub writes nothing" do
    hold(catalog_card_seasons(:portal_one).id, gained_at: 2.hours.ago)
    legendary = catalog_card_seasons(:legendary_card_one).id
    hold(legendary, gained_at: 1.hour.ago)
    sign_in(@player)

    get home_path(locale: :en)
    assert_select ".hub-showcase h2", "Golden Crown"
    assert_select ".hub-showcase form button", "Repost"

    trade_away_only_copy(legendary)
    assert_empty written_statements { get home_path(locale: :en) }

    assert_response :success
    assert_select ".hub-showcase h2", "Portal"
    assert_select ".hub-showcase form[action='/en/cards/portal/seasons/1/repost'] button", "Repost"
  end

  test "a player's hub: the menu, the latest notable card held, the daily panel and the sets in progress" do
    gained = 1.hour.ago.change(usec: 0)
    Game::Holding.create!(player_id: @player.id, card_season_id: catalog_card_seasons(:portal_one).id, quantity: 2, last_gained_at: gained)
    Game::SetTier.insert_all!([ { player_id: @player.id, set_id: catalog_sets(:valve_one).id, tier: "complete", reached_by: "trade",
      reached_at: gained, created_at: gained, updated_at: gained } ])
    3.times { create_pack(@player) }
    sign_in(@player)

    get home_path(locale: :fr)

    assert_response :success
    assert_select ".hub[data-controller=hub-menu]"
    assert_select "nav.hub-menu[aria-label=?] ol.hub-menu__list > li", "Menu du pont", count: 9
    assert_equal %w[1 2 3 4 5 6 7 8 9], menu_items.map { it["aria-keyshortcuts"] }
    assert_equal %w[01 02 03 04 05 06 07 08 09], css_select(".hub-menu .menu-item__number").map(&:text)

    # 01: the booster screen, its reserve in a lime badge.
    assert_select ".hub-menu a.menu-item[href='/fr/booster'][data-hub-menu-target=item][data-turbo-prefetch=false]" do
      assert_select ".menu-item__label", "Ouvrir une capsule"
      assert_select ".menu-item__badge[aria-hidden=true]", "3"
      assert_select ".visually-hidden", "3 capsules en réserve"
      assert_select "svg.menu-item__arrow"
    end
    # 02: the collection, unique cards owned out of the season's.
    assert_select ".hub-menu a.menu-item[href='/fr/library'][aria-keyshortcuts='2']" do
      assert_select ".menu-item__label", "Collection"
      assert_select ".menu-item__meta", "1/5"
      assert_select ".visually-hidden", "1 carte unique sur 5"
    end
    # 03: every card of the catalog.
    assert_select ".hub-menu a.menu-item[href='/fr/library/cards'][aria-keyshortcuts='3'][data-hub-menu-target=item][data-turbo-prefetch=false]" do
      assert_select ".menu-item__label", "Toutes les cartes"
    end
    # 06: the public feed.
    assert_select ".hub-menu a.menu-item[href='/fr/feed'][aria-keyshortcuts='6']" do
      assert_select ".menu-item__label", "Fil d'activité"
    end
    # 08: the rules of the game.
    assert_select ".hub-menu a.menu-item[href='/fr/how-it-works'][aria-keyshortcuts='8'][data-hub-menu-target=item][data-turbo-prefetch=false]" do
      assert_select ".menu-item__label", "Comment ça marche"
    end
    # 09: the donation page, in a new tab, last.
    support = menu_items.last
    assert_equal [ "9", "item", "https://buymeacoffee.com/theiereman", "_blank" ],
      [ support["aria-keyshortcuts"], support["data-hub-menu-target"], support["href"], support["target"] ]
    assert_equal %w[noopener noreferrer external], support["rel"].split
    assert_equal [ "Soutenir", "(nouvel onglet)" ], [ support.at_css(".menu-item__label").text, support.at_css(".visually-hidden").text.strip ]
    assert support.at_css("svg.menu-item__external")
    assert_nil support["data-action"]
    # 04: the trades screen, the waiting count greyed at zero.
    assert_select ".hub-menu a.menu-item[href='/fr/trades'][aria-keyshortcuts='4']" do
      assert_select ".menu-item__label", "Échanges"
      assert_select ".menu-item__badge.menu-item__badge--alert.menu-item__badge--zero", "0"
      assert_select ".visually-hidden", "0 échange en attente de vous"
    end
    # 07: the achievements screen, none earned yet.
    assert_select ".hub-menu a.menu-item[href='/fr/achievements'][aria-keyshortcuts='7'][data-hub-menu-target=item][data-turbo-prefetch=false]" do
      assert_select ".menu-item__label", "Succès"
      assert_select ".menu-item__meta[aria-hidden=true]", "0/10"
      assert_select ".visually-hidden", "0 succès obtenu sur 10"
    end
    assert_select ".hub-menu [aria-disabled]", false

    # The showcase: the tier 4 card held, its line (rarity and
    # number; no main theme, so no genre) and its page.
    assert_select ".hub-showcase:not(.hub-showcase--empty)" do
      assert_select ".hub-showcase__kicker", "Dernière obtention"
      assert_select ".card.card--xl", 1
      assert_select "h2.hub-showcase__name", "Portal"
      assert_select ".hub-showcase__rarity.hub-showcase__rarity--4 svg.pixel-icon"
      assert_select ".hub-showcase__rarity span", "#{epic_name(:fr)} · S1 · #4"
      assert_select "a.button.button--secondary[href='/fr/cards/portal/seasons/1']", "Voir la fiche"
      assert_select "form.button-form[method=post][action='/fr/cards/portal/seasons/1/repost'] button.button--secondary", "Reposter"
    end

    # The daily panel, its button the view's one primary.
    assert_select "section.daily-booster.panel--quiet[aria-labelledby=daily-booster-title]" do
      assert_select "h2#daily-booster-title", "Capsule quotidienne"
      assert_select ".daily-booster__state--ready", "Prête"
      assert_select ".daily-booster__text", "Une capsule offerte chaque jour. Elle rejoint votre réserve."
      assert_select "form[action='/fr/daily-bonus'][method=post] button.button--primary.button--small", "Récupérer"
    end
    assert_select "main .button--primary", 1

    # The sets in progress: the season's one set, completed by the latest
    # gain, owned out of its size.
    assert_select ".hub-sets h2", "Sets en cours"
    assert_select ".hub-sets a.set-row.set-row--progress[href='/fr/library/studio/valve']" do
      assert_select ".set-row__name[aria-hidden=true]", "Valve"
      assert_select ".set-row__kind", "Studio"
      assert_select ".set-tier--complete .set-tier__stamp"
      assert_select ".set-tier--complete", "Complet"
      assert_select ".set-row__count", "1/1"
      assert_select ".visually-hidden", "Valve, studio, 1 carte sur 1, complet"
      assert_select ".set-row__track[aria-hidden=true] progress.set-row__bar[value='1'][max='1']"
      assert_select ".set-row__tick", false
    end
    assert_select ".hub-sets a.button--link[href='/fr/library']", "Tout voir"

    # A player has no sign-in panel; the page carries no inline style.
    assert_select "#sign-in-panel", false
    assert_select "[style]", false
  end

  test "the first card the player chose shows under VITRINE, any rarity; with none left, the automatic card under DERNIÈRE OBTENTION" do
    common, rare, portal = catalog_card_seasons(:common_card_one, :rare_card_one, :portal_one).map(&:id)
    [ common, rare, portal ].each { Game::Holding.create!(player_id: @player.id, card_season_id: it, quantity: 1) }
    [ rare, common ].each { Game::AddToShowcase.new.call(player: @player, card_season_id: it).value! }
    sign_in(@player, origin: "/fr")

    get home_path(locale: :fr)
    assert_select ".hub-showcase:not(.hub-showcase--empty)" do
      assert_select ".hub-showcase__kicker", "Vitrine"
      assert_select "h2.hub-showcase__name", "Profondeurs bleues"
      assert_select "a.button.button--secondary[href='/fr/cards/blue-depths/seasons/1']", "Voir la fiche"
      assert_select "form.button-form[action='/fr/cards/blue-depths/seasons/1/repost'] button", "Reposter"
    end

    [ rare, common ].each { Game::RemoveFromShowcase.new.call(player: @player, card_season_id: it).value! }
    get home_path(locale: :fr)
    assert_select ".hub-showcase__kicker", "Dernière obtention"
    assert_select "h2.hub-showcase__name", "Portal"
  end

  test "a player holding no tier 4 card sees the empty showcase, its primary opening a booster" do
    hold(fixture_tier_ids.first, gained_at: 1.hour.ago)
    create_pack(@player)
    sign_in(@player)

    get home_path(locale: :en)

    assert_select ".hub-showcase.hub-showcase--empty" do
      assert_select ".hub-showcase__kicker", false
      assert_select ".hub-showcase__frame[aria-hidden=true] .hub-showcase__outline svg.hub-showcase__wordmark"
      assert_select ".hub-showcase__outline [data-controller~=wordmark-shine], .hub-showcase__outline .wordmark-sweep__frames", false
      assert_select "h2.hub-showcase__name", "Open your first capsule"
      assert_select ".hub-showcase__line", "Your finest card will show here."
      assert_select "a.button.button--primary[href='/en/booster']", "Open a capsule"
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
    assert_select ".hub-showcase--empty button.button[type=button][disabled]", "Open a capsule"
    assert_select ".hub-showcase--empty .hub-showcase__reason", "Reserve empty"
    assert_select "main form[action='/en/packs']", false
  end

  test "on the hub the packs chip's countdown refreshes the page; elsewhere it refreshes the chip alone" do
    create_pack(@player, available_at: 5.minutes.from_now)
    sign_in(@player)

    get home_path(locale: :en)
    assert_select ".top-bar .packs-chip__next[data-controller=countdown][data-countdown-refresh-value=true]"
    assert_select ".top-bar .packs-chip__next[data-countdown-refresh-url-value='/en/packs-chip']"

    get card_path(locale: :en, slug: "portal")
    assert_select ".top-bar .packs-chip__next[data-controller=countdown][data-countdown-refresh-value=false][data-countdown-refresh-url-value='/en/packs-chip']"
  end

  test "a full reserve: the daily panel says so in orange and its button is disabled" do
    10.times { create_pack(@player) }
    sign_in(@player)

    get home_path(locale: :fr)

    assert_select ".daily-booster" do
      assert_select ".daily-booster__state--full", "Réserve pleine"
      assert_select ".daily-booster__text", "Ouvrez une capsule pour récupérer celle du jour."
      assert_select "button.button.button--small[type=button][disabled]", "Récupérer"
      assert_select "form", false
    end
  end

  test "once the day's booster is collected, the daily panel stays: collected, with the countdown to 00:00 UTC and its bar" do
    Game::CollectDailyBonus.new.call(player: @player).value!
    sign_in(@player)

    travel_to(Time.current.utc.change(hour: 22, min: 30, sec: 15)) do
      get home_path(locale: :en)
      next_day = Time.current.utc.tomorrow.beginning_of_day

      assert_select ".daily-booster.daily-booster--collected" do
        assert_select ".daily-booster__state", "Collected"
        assert_select ".daily-booster__text", "A capsule joins your reserve. The next one will be ready on #{next_day.strftime("%Y-%m-%d")} 00:00 UTC."
        assert_select ".daily-booster__text time[datetime='#{next_day.iso8601}'][data-controller=local-time]"
        assert_select ".daily-booster__next[data-controller=countdown][data-countdown-seconds-value='5385'][data-countdown-hours-value=true]" do
          assert_select ".daily-booster__next-label", "Next in"
          assert_select ".daily-booster__clock[data-countdown-target=clock]", "01:29:45"
          assert_select "progress.daily-booster__bar[max='86400'][value='81015']"
          assert_select ".visually-hidden", "Next capsule: #{next_day.strftime("%Y-%m-%d")} 00:00 UTC"
          assert_select ".visually-hidden time[datetime='#{next_day.iso8601}']"
        end
        assert_select "button, a.button, form", false
      end
    end
    assert_select ".hub-menu a.menu-item[href='/en/booster'] .menu-item__badge"
  end

  test "the collection's meta counts the games held in any edition, out of the published season's cards" do
    player = accounts_players(:player)
    Game::Holding.create!(player_id: player.id, card_season_id: catalog_card_seasons(:portal_one).id, quantity: 1)
    publish_sets_draft
    sign_in(player)

    get home_path(locale: :en)

    assert_select ".hub-menu a.menu-item[href='/en/library'] .menu-item__meta", "1/150"
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
      assert_select item, ".menu-item__label", "Open a capsule"
      assert_select item, ".menu-item__badge", false
    end
    assert_select ".hub-menu a.menu-item[href='/en/library'] .menu-item__meta", "0/5"
    assert_select ".hub-menu a.menu-item[href='/en/library/cards'][aria-keyshortcuts='3'] .menu-item__label", "All cards"
    assert_select ".hub-menu a.menu-item[href='/en/how-it-works'][aria-keyshortcuts='8']", /How it works/
    assert_select ".hub-menu a.menu-item[href='https://buymeacoffee.com/theiereman'][target=_blank][aria-keyshortcuts='9'] .menu-item__label", "Support"

    assert_select ".hub-invitation" do
      assert_select "h2.hub-invitation__title", "Your Steam games, as collectible cards."
      assert_select ".hub-showcase__line", "Open capsules, complete sets, trade with your friends."
      assert_select "button.button.button--primary[type=button][aria-haspopup=dialog][data-dialog-opener-dialog-value=sign-in-panel]", "Open my first capsules"
    end
    assert_select ".hub-showcase:not(.hub-invitation)", false
    assert_select ".daily-booster", false
    assert_select ".hub-sets a.set-row .set-row__count", "0/1"
    assert_select "main form[action='/auth/steam']", false
    assert_select "a[href='/en/back-office']", false
    assert_select ".top-bar__start a.button", false
  end

  test "a visitor gets the sign-in panel: its title, the official image focused first, the links to the terms and the privacy notice, and the close button" do
    get home_path(locale: :fr)

    assert_select "body > dialog#sign-in-panel.modal[aria-labelledby=sign-in-panel-title][data-controller=dialog]" do
      assert_select ".panel.panel--brackets"
      assert_select "p#sign-in-panel-title", "Connectez-vous pour jouer"
      assert_select "button.modal__close[type=button][aria-label=Fermer][data-action='dialog#close'] svg.pixel-icon"
      assert_select "form.steam-sign-in[action='/auth/steam'] input[name=origin][value='/fr']"
      assert_select "button.steam-sign-in__button[autofocus] img[src*='sits_01']"
      assert_equal [ "/fr/legal#legal-terms", "/fr/legal#legal-privacy" ], css_select("dialog#sign-in-panel a").map { it["href"] }
    end
  end

  test "every form posting to /auth/steam is the official Steam image" do
    get home_path(locale: :en)

    forms = css_select("form[action='/auth/steam']")
    assert_equal 2, forms.size, "the top bar's and the sign-in panel's"
    assert forms.all? { it.classes.include?("steam-sign-in") && it.at_css("button.steam-sign-in__button img[src*='sits_01']") }
    assert_select "a[href*='/auth/steam']", false
  end

  test "a player with five sets in progress sees the board's first four, and See all leads to the collection" do
    season, cards = published_cards(60)
    [ 3, 2, 5, 9, 4 ].each_with_index do |held, index|
      members = cards.shift(12)
      insert_theme(members, key: %w[roguelike rpg horror cosy pirates][index], season:)
      hold_all(@player, members.first(held))
    end
    sign_in(@player)

    get home_path(locale: :en)

    expected = Game::SetBoard.call(@player, season:).in_progress.first(4).map { Catalog::Set.find(it.set_id) }
    assert_equal 4, expected.size
    assert_select ".hub-sets h2", "Sets in progress"
    assert_equal expected.map { "/en/library/#{it.kind}/#{it.key}" }, css_select(".hub-sets a.set-row").map { it["href"] }
    assert_equal [ "Horror", "RPG", "Pirates", "Cosy" ], css_select(".hub-sets .set-row__name").map(&:text)
    assert_select ".hub-sets a.button--link[href='/en/library']", "See all"
  end

  test "a set completed before the latest gain leaves the hub's sets in progress; none left, no panel" do
    Game::Holding.create!(player_id: @player.id, card_season_id: catalog_card_seasons(:portal_one).id, quantity: 1)
    sign_in(@player)

    get home_path(locale: :en)

    assert_select ".hub-sets", false
  end

  test "no published season: no set rows and no collection meta" do
    catalog_seasons(:one).update_columns(status: "draft", published_at: nil)

    get home_path(locale: :en)
    assert_select ".hub-sets", false
    assert_select ".hub-menu .menu-item__meta", false

    sign_in(@player)
    get home_path(locale: :en)
    assert_select ".hub-sets", false
    assert_select ".hub-menu .menu-item__meta", count: 1, text: "0 online"
    assert_select ".daily-booster", false
    assert_select ".hub-showcase--empty"
  end

  test "the hub shows the goal panel with the Brotherhood line and the real target, in both languages, to a visitor too" do
    Game::WeeklyContribution.create!(player_id: @player.id, week_start: Game::WeeklyGoal.week_start(Time.current) - 7, openings: 1)
    Game::SumWeeklyGoalJob.new.perform
    Game::WeeklyGoal.where(week_start: Game::WeeklyGoal.week_start(Time.current)).update_all(total: 100, target: 50_000)

    get home_path(locale: :en)
    assert_select "#community-goal .hub-goal__line", text: "The Brotherhood invites its members to join forces and open 50,000 capsules this week."
    assert_select "#community-goal .hub-goal__figures", text: "100 / 50,000"
    assert_select "#community-goal .hub-goal__segment", count: 24
    assert_select "#community-goal .hub-goal__segment--lit", count: 0

    get home_path(locale: :fr)
    assert_select "#community-goal .hub-goal__line", text: /\ALa Confrérie invite ses membres à unir leurs efforts pour ouvrir 50[\s\u00a0\u202f]000 capsules cette semaine\.\z/
  end

  test "a reached goal reads Objectif atteint with a full gauge, for a visitor and a player, in both languages" do
    week = Game::WeeklyGoal.week_start(Time.current)
    Game::WeeklyGoal.create!(week_start: week, total: 210, target: 200)

    get home_path(locale: :en)
    assert_select "#community-goal .hub-goal__status", text: "Goal reached"
    assert_select "#community-goal .hub-goal__figures", text: "210 / 200"
    assert_select "#community-goal .hub-goal__segment--lit", count: 24
    assert_select "#community-goal .hub-goal__previous", false

    sign_in(@player, origin: "/fr")
    get home_path(locale: :fr)
    assert_select "#community-goal .hub-goal__status", text: "Objectif atteint"
    assert_select "#community-goal .hub-goal__segment--lit", count: 24
  end

  test "after the rollover the panel shows the new week's empty gauge and target, and last week's final count" do
    week = Game::WeeklyGoal.week_start(Time.current)
    Game::WeeklyGoal.create!(week_start: week - 7, total: 180, target: 200)
    Game::WeeklyGoal.create!(week_start: week, total: 0, target: 250)

    get home_path(locale: :fr)
    assert_select "#community-goal .hub-goal__status", false
    assert_select "#community-goal .hub-goal__figures", text: "0 / 250"
    assert_select "#community-goal .hub-goal__segment--lit", count: 0
    assert_select "#community-goal .hub-goal__previous", text: "Semaine dernière : 180 / 200 · objectif manqué"

    Game::WeeklyGoal.where(week_start: week - 7).update_all(total: 260)
    get home_path(locale: :en)
    assert_select "#community-goal .hub-goal__previous", text: "Last week: 260 / 200 · goal reached"
  end

  def earn_goal_reward(player = @player)
    week = Game::WeeklyGoal.week_start(Time.current) - 7
    Game::WeeklyGoal.find_or_create_by!(week_start: week) { it.assign_attributes(total: 200, target: 200) }
    Game::WeeklyContribution.create!(player_id: player.id, week_start: week, openings: 1)
    Game::GrantGoalReward.new.call(player:, week_start: week).value!
    week
  end

  test "a contributor's waiting goal reward shows its claim slot in the goal panel, outside the broadcast part" do
    week = earn_goal_reward
    Game::WeeklyGoal.create!(week_start: week + 7, total: 0, target: 250)

    get home_path(locale: :en)
    assert_select "#goal-reward", false

    sign_in(@player, origin: "/fr")
    get home_path(locale: :fr)

    assert_select "#community-goal > #community-goal-progress + #goal-reward.hub-goal__claim--ready" do
      assert_select "form[action='/fr/goal-rewards/#{week.iso8601}'][method=post] button.button--secondary.button--small" \
                    "[aria-label=?]", "Récupérer la capsule de récompense", text: "Récupérer"
    end
    assert_select "#community-goal-progress #goal-reward", false
    assert_select "#community-goal-progress .hub-goal__previous"
    assert_select "#toasts .toast[data-toast-once]", false
    assert_select "[style]", 0

    sign_in(accounts_players(:moderator))
    get home_path(locale: :en)
    assert_select "#goal-reward", false
  end

  test "with a full reserve the claim slot disables its button and says why; collected, it reads Collected" do
    week = earn_goal_reward
    Game::FillBank.new.call(player: @player).value!
    sign_in(@player)

    get home_path(locale: :en)
    assert_select "#goal-reward.hub-goal__claim--full" do
      assert_select "button[disabled][aria-label=?]", "Collect the reward capsule", text: "Collect"
      assert_select "form", 0
      assert_select ".hub-goal__claim-text", "Open a capsule to collect your rare capsule."
    end
    get home_path(locale: :fr)
    assert_select "#goal-reward .hub-goal__claim-text", "Ouvrez une capsule pour récupérer votre capsule rare."

    Game::OpenPack.new.call(player: @player).value!
    Game::ClaimGoalReward.new.call(player: @player, week_start: week).value!

    get home_path(locale: :fr)
    assert_select "#goal-reward.hub-goal__claim--collected" do
      assert_select ".hub-goal__claim-state", "Récupérée"
      assert_select "form, button", 0
    end
    get home_path(locale: :en)
    assert_select "#goal-reward .hub-goal__claim-state", "Collected"
  end

  def stream_names
    css_select("turbo-cable-stream-source").map { Turbo::StreamsChannel.verified_stream_name(it["signed-stream-name"]) }
  end

  def open_pack_of(player, card_season_id)
    create_pack(player, cards: [ card_season_id ] * 5)
    Game::OpenPack.new.call(player:).value!
  end

  test "the hub's LIVE ticker shows pulls of Epic or better, first discoveries, trades and sets, never a repost nor a filler" do
    @player.update!(persona_name: "Hugo")
    quiet = accounts_players(:moderator).tap { it.update!(persona_name: "Quiet") }
    open_pack_of(quiet, catalog_card_seasons(:rare_card_one).id)
    open_pack_of(@player, fixture_tier_ids[3])
    Game::FirstDiscovery.where(card_season_id: fixture_tier_ids[0]).delete_all
    open_pack_of(@player, fixture_tier_ids[0])
    partner = accounts_players(:administrator).tap { it.update!(persona_name: "Léa") }
    conclude_trade(@player, partner, offer: { fixture_tier_ids[2] => 1 }, request: { fixture_tier_ids[1] => 1 })
    Game::Holding.create!(player_id: @player.id, card_season_id: fixture_tier_ids[4], quantity: 1)
    Game::RepostCard.new.call(player: @player, card_season_id: fixture_tier_ids[4]).value!

    get home_path(locale: :en)

    assert_select "body > main#main + #live-ticker.ticker[aria-hidden=true][data-turbo-permanent][data-controller=ticker]" do
      assert_select ".live-marker .live-marker__text", "Live"
      assert_select ".ticker__run .ticker__item", 8
      assert_select ".ticker__item .ticker__separator"
      assert_select ".ticker__item .ticker__first", count: 1, text: "First discovery"
      assert_select ".ticker__rarity--epic", count: 5, text: "Epic"
      assert_select ".ticker__item", count: 1, text: /Hugo and Léa traded Blue Depths for Green Hills/
      assert_select ".ticker__trade", count: 1, text: "Trade"
      assert_select ".ticker__item", count: 1, text: /Hugo completes the Valve set\./ do
        assert_select ".ticker__tier.feed__tier--complete .feed__tier-stamp"
        assert_select ".ticker__tier", "Complete"
        assert_select ".ticker__rarity, .card", 0
      end
      assert_select ".ticker__item", text: /reposted/, count: 0
      assert_select ".ticker__item", text: /Quiet/, count: 0
      assert_select "#live-ticker-queue[hidden]"
      assert_select "a, button, [tabindex]", 0
    end
    assert_select "[style]", 0
    assert_equal %w[goal:en live:en], stream_names
  end

  test "the hub listens to the French streams in French, for a visitor and a player" do
    get home_path(locale: :fr)
    assert_equal %w[goal:fr live:fr], stream_names
    assert_select "#live-ticker .live-marker__text", "Live"

    sign_in(@player, origin: "/fr")
    get home_path(locale: :fr)
    assert_includes stream_names, "goal:fr"
    assert_select "#community-goal"
  end

  def assert_hub_queries(count)
    ActiveRecord::Base.connection.clear_query_cache
    assert_queries_count(count) { get home_path(locale: :en) }
    assert_response :success
  end

  test "a hub load costs a fixed number of queries, however long the player's history" do
    Game::Holding.create!(player_id: @player.id, card_season_id: catalog_card_seasons(:portal_one).id, quantity: 2)
    sign_in(@player)
    earn_goal_reward
    Game::SumWeeklyGoalJob.new.perform

    # Player lookup, published season, the weekly goal (one read once the job
    # has created the week's row), bank (count, next pack, daily claim), the
    # goal reward's claim slot,
    # showcase (cards chosen, card held, card view), collection (owned, total), sets (the
    # player's standings, the popular fill, which finds no other set here, so no figures
    # and no set to name),
    # the top bar's copies per tier, menu 05's friends online, menu 07's
    # achievements earned, the trades
    # waiting (menu 04 and the tab bar share one count) and the LIVE ticker's
    # entries (none here, so no players or cards).
    assert_hub_queries(PLAYER_HUB_QUERIES)
    assert_select ".hub-showcase .card"

    # Many more opened packs add no query.
    common = Array.new(Game::Pack::SIZE, catalog_card_seasons(:common_card_one).id)
    60.times { |index| create_pack(@player, cards: common, opened_at: (index + 1).minutes.ago) }
    assert_hub_queries(PLAYER_HUB_QUERIES)
    assert_select ".hub-showcase .card"

    delete session_path(locale: :en)
    # Published season, collection total, the popular sets, their figures
    # and the sets naming them, the ticker's entries.
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

  test "a pending welcome sits above the menu at no query's cost, and the sign-in still focuses the first menu item" do
    sign_in(@player, origin: "/fr")
    get home_path(locale: :en)
    queries_without_welcome = count_hub_queries
    assert_operator queries_without_welcome, :>, 0

    @player.update_columns(welcome_pending: true)
    sign_in(@player, origin: "/fr")
    follow_redirect!

    assert_select ".hub[data-hub-menu-focus-first-value=true] > header + #welcome-panel + .hub-menu"
    assert_equal queries_without_welcome, count_hub_queries
  end

  def count_hub_queries
    ActiveRecord::Base.connection.clear_query_cache
    queries = 0
    counter = ->(*, payload) { queries += 1 unless payload[:name].in?([ "SCHEMA", "TRANSACTION" ]) || payload[:cached] }
    ActiveSupport::Notifications.subscribed(counter, "sql.active_record") { get home_path(locale: :en) }
    queries
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

  test "a visitor reads the French legal page: six sections, the exact ownership notice, the donation link in a new tab" do
    configure_legal

    get legal_path(locale: :fr)

    assert_response :success
    assert_select "html[lang=fr]"
    assert_select "title", "Mentions légales et confidentialité"
    assert_select "main h1#legal-heading", "Mentions légales et confidentialité"
    assert_equal [ "Éditeur et hébergeur", "Steam, Valve et les jeux", "Conditions d'utilisation", "Confidentialité", "Code source", "Soutenir gameble" ],
      css_select("main section.legal__section h2").map(&:text)
    assert_select ".legal__ownership", OWNERSHIP_NOTICE
    assert_select ".legal__affiliation", /n'est affilié ni à Valve ni à Steam/
    assert_select ".legal__section", text: /CNIL/
    donation = css_select("main a.legal__donation").sole
    assert_equal [ "https://buymeacoffee.com/theiereman", "_blank", "Soutenir (nouvel onglet)" ],
      [ donation["href"], donation["target"], donation.text.squish ]
    assert_includes donation["rel"].split, "noopener"
    assert_select "section[aria-labelledby=legal-support]", text: /Ils passent par Buy Me a Coffee/
    source = css_select("main a.legal__source").sole
    assert_equal [ "https://github.com/theiereman/gameble", "_blank", "Code source (nouvel onglet)" ],
      [ source["href"], source["target"], source.text.squish ]
    assert_includes source["rel"].split, "noopener"
    assert_select "section[aria-labelledby=legal-source]", text: /sous licence GNU AGPL v3\.0/
    assert_select "[style]", 0
  end

  test "a signed-in player reads the English legal page" do
    configure_legal
    sign_in(@player)

    get legal_path(locale: :en)

    assert_response :success
    assert_select "html[lang=en]"
    assert_select "main h1", "Legal notice and privacy"
    assert_equal [ "Publisher and host", "Steam, Valve and the games", "Terms of use", "Privacy", "Source code", "Support gameble" ],
      css_select("main section.legal__section h2").map(&:text)
    assert_select ".legal__ownership", "All artwork belongs to the games' publishers and their artists, whom we respect."
    assert_equal "Support (new tab)", css_select("main a.legal__donation").sole.text.squish
    assert_select "section[aria-labelledby=legal-support]", text: /They go through Buy Me a Coffee/
    assert_equal "Source code (new tab)", css_select("main a.legal__source").sole.text.squish
    assert_select "section[aria-labelledby=legal-source]", text: /under the GNU AGPL v3\.0 license/
  end

  test "the configured contact is a mailto link, and the host's name and address are shown" do
    configure_legal(contact_email: "contact@example.test", host_name: "Example Hosting", host_address: "1 rue de l'Exemple, 75000 Paris")

    get legal_path(locale: :en)

    assert_response :success
    assert_select ".legal__contact a[href=?]", "mailto:contact@example.test", "contact@example.test"
    assert_select ".legal__host-name", "Example Hosting"
    assert_select ".legal__host-address", "1 rue de l'Exemple, 75000 Paris"
    assert_select ".legal__access", 'access: from the settings, with "Export" under "My data", which downloads a copy of your data in a reusable file;'
    assert_select ".legal__access a", false
  end

  test "without a configured contact or host, those lines are left out and the page still renders" do
    configure_legal

    get legal_path(locale: :en)

    assert_response :success
    assert_select ".legal__contact", false
    assert_select ".legal__host", false
    assert_select "a[href^='mailto:']", false
    assert_select ".legal__fact dt", "Publisher"
    assert_select ".legal__access", 'access: from the settings, with "Export" under "My data", which downloads a copy of your data in a reusable file;'
    assert_no_match(/contact address above/, response.body)

    get legal_path(locale: :fr)
    assert_select ".legal__access", "accès : depuis les paramètres, avec « Exporter » dans « Mes données », qui télécharge une copie de vos données dans un fichier réutilisable ;"
  end

  test "with a contact configured, every line that sends the reader to the publisher carries the mailto link" do
    configure_legal(contact_email: "contact@example.test")

    get legal_path(locale: :fr)

    assert_response :success
    assert_select ".legal__updated", "Dernière mise à jour : 20 octobre 2026"
    %w[.legal__moderation .legal__notice .legal__rectification .legal__objection .legal__death .legal__banned].each do |line|
      assert_select "#{line} a.legal__link[href=?]", "mailto:contact@example.test", "contact@example.test"
    end
    assert_select ".legal__moderation", /La décision est toujours prise par une personne/
    assert_select ".legal__visibility", /public par défaut/
    assert_select ".legal__section li", /\ASentry .* Données hébergées dans l'Union européenne ;\z/
  end

  test "without a contact, those lines name the publisher in plain words" do
    configure_legal

    get legal_path(locale: :en)

    assert_response :success
    assert_select ".legal__updated", "Last updated: 20 October 2026"
    assert_select ".legal__moderation", /by writing to the publisher\.\z/
    assert_select ".legal__notice", /write to the publisher with the page's address/
    assert_select ".legal__rectification", /write to the publisher;\z/
    assert_select ".legal__objection", "objection: make your profile private in the settings, or write to the publisher;"
    assert_select ".legal__death", /\Aafter your death: tell the publisher who/
    assert_select ".legal__banned", /write to the publisher to contest the decision, obtain your data/
    assert_select "a[href^='mailto:']", false
  end

  test "the privacy section says how long each kind of data is kept, before the deletion paragraph that refers to it" do
    configure_legal

    get legal_path(locale: :fr)

    assert_response :success
    assert_select ".legal__retention li", 8
    retention = css_select(".legal__retention").text
    [ "trois ans", "un an", "30 jours", "tant que la suspension dure" ].each { assert_includes retention, it }
    assert_select ".legal__retention li", "les erreurs techniques reçues par Sentry : 30 jours ;"
    assert_select ".legal__retention li", "les sauvegardes de la base de données, chiffrées et conservées en France : les 7 dernières sauvegardes quotidiennes, soit 7 jours en temps normal ; un compte supprimé en disparaît au bout de 7 jours, un peu plus si une sauvegarde a échoué ;"
    assert_select ".legal__retention + p", /pendant les durées indiquées plus haut\.\z/

    get legal_path(locale: :en)

    assert_select ".legal__retention li", 8
    retention = css_select(".legal__retention").text
    [ "three years", "one year", "30 days", "as long as the suspension lasts" ].each { assert_includes retention, it }
    assert_select ".legal__retention li", "technical errors received by Sentry: 30 days;"
    assert_select ".legal__retention li", "the database backups, encrypted and kept in France: the last 7 daily backups, that is 7 days in normal times; a deleted account is gone from them after 7 days, a little longer if a backup failed;"
    assert_select ".legal__retention + p", /for the periods given above\.\z/
  end

  test "the deletion paragraph names the game data an account deletion erases, completions as set tiers" do
    configure_legal
    erased = {
      fr: [ "votre dernière activité", "votre collection", "votre vitrine", "vos paliers de sets", "vos succès", "vos capsules", "vos bonus du jour",
            "vos récompenses de l'objectif communautaire", "vos amitiés", "vos invitations", "votre code ami", "vos entrées du fil d'activité" ],
      en: [ "your latest activity", "your collection", "your showcase", "your set tiers", "your achievements", "your capsules", "your daily bonuses",
            "your community goal rewards", "your friendships", "your invitations", "your friend code", "your activity feed entries" ]
    }

    erased.each do |locale, phrases|
      get legal_path(locale:)

      deletion = css_select(".legal__retention + p").text
      phrases.each { assert_includes deletion, it }
      assert_no_match(/complétés|completed sets/, deletion)
    end
  end

  test "the outside services name OVH, which keeps the encrypted backups in France" do
    configure_legal

    get legal_path(locale: :fr)

    assert_response :success
    assert_select ".legal__backup_host", "OVH SAS conserve les sauvegardes de la base de données, chiffrées avant de quitter le serveur : il ne peut pas les lire. Données hébergées en France ;"

    get legal_path(locale: :en)

    assert_select ".legal__backup_host", "OVH SAS stores the database backups, encrypted before they leave the server, so it cannot read them. Data hosted in France;"
  end

  test "neither locale calls a deleted account anonymised" do
    configure_legal

    %i[fr en].each do |locale|
      get legal_path(locale:)

      assert_response :success
      assert_no_match(/anonymis/i, response.body)
    end
  end

  test "a signed-in player finds the legal page beside the version, in their locale" do
    sign_in(@player)

    get home_path(locale: :en)

    assert_select "body > .app-version a.app-version__legal[href=?]", "/en/legal", "Legal notice"

    get home_path(locale: :fr)

    assert_select "body > .app-version a.app-version__legal[href=?]", "/fr/legal", "Mentions légales"
  end

  test "the privacy section opens by naming the controller of the data, with the contact when there is one" do
    configure_legal(contact_email: "contact@example.test")

    get legal_path(locale: :fr)

    assert_select "#legal-privacy + p.legal__controller",
      "Le responsable du traitement de vos données est Thomas Eyermann, éditeur de gameble, joignable à contact@example.test."
    assert_select ".legal__controller a.legal__link[href=?]", "mailto:contact@example.test"

    get legal_path(locale: :en)

    assert_select "#legal-privacy + p.legal__controller",
      "The controller of your data is Thomas Eyermann, publisher of gameble, reachable at contact@example.test."
  end

  test "without a contact, the controller line names the publisher only" do
    configure_legal

    get legal_path(locale: :fr)

    assert_select "#legal-privacy + p.legal__controller", "Le responsable du traitement de vos données est Thomas Eyermann, éditeur de gameble."
    assert_select ".legal__controller a", false

    get legal_path(locale: :en)

    assert_select "#legal-privacy + p.legal__controller", "The controller of your data is Thomas Eyermann, publisher of gameble."
  end

  test "an older browser reads the legal page, which the public card page's footer links to" do
    configure_legal

    get legal_path(locale: :en), headers: { "User-Agent" => "Mozilla/5.0 (Macintosh; Intel Mac OS X 11.6; rv:92.0) Gecko/20100101 Firefox/92.0" }

    assert_response :success
    assert_select ".legal__ownership"
  end

  test "the showcase floats an epic card with purple rays" do
    hold(catalog_card_seasons(:portal_one).id, gained_at: 1.hour.ago)
    sign_in(@player)

    get home_path(locale: :en)
    assert_response :success
    assert_select ".hub-showcase:not(.hub-showcase--empty) .hub-showcase__stage .card-float .card-rays.card-rays--epic", 1
    assert_select ".hub-showcase__stage .card-float .card.card--xl", 1
    assert_select ".hub-showcase__ground", 1
  end
end

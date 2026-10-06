require "test_helper"
require_relative "../support/counting_rate_limit"
require_relative "../support/game_packs"

# Opening a pack from the hub's menu and the pack result page (R9, CAP-4):
# end to end, the result page, and every refusal.
class PacksControllerTest < ActionDispatch::IntegrationTest
  include CountingRateLimit
  include GamePacks

  NEW_STEAM_ID = "76561197960287930".freeze

  setup do
    Game::DrawPool.reset!
    OmniAuth.config.test_mode = true
  end

  teardown do
    OmniAuth.config.mock_auth.delete(:steam)
    OmniAuth.config.test_mode = false
  end

  def sign_in(steam_id, origin: "/en")
    OmniAuth.config.mock_auth[:steam] = OmniAuth::AuthHash.new(provider: "steam", uid: "https://steamcommunity.com/openid/id/#{steam_id}")
    post "/auth/steam", params: { origin: }
    follow_redirect!
    assert session[:player_id]
  end

  # Menu 01 of the hub: the open-pack button, or the disabled item.
  def open_item
    css_select(".hub-menu .menu-item[aria-keyshortcuts='1']").sole
  end

  def reserve_badge
    open_item.at_css(".menu-item__badge").text
  end

  REVEAL = "[data-turbo-mount-pack-reveal-component-value=PackReveal]".freeze

  # The reveal island's props, or nil when the page has none.
  def reveal_props
    element = css_select(REVEAL).first
    element && JSON.parse(element["data-turbo-mount-pack-reveal-props-value"])
  end

  def end_buttons
    css_select(".pack-end .button").map { |button| button.text.strip }
  end

  test "a new player opens a pack: the reveal comes once, with the cards in order, then the faces on every later visit" do
    sign_in(NEW_STEAM_ID)
    player = Accounts::Player.find_by!(steam_id: NEW_STEAM_ID)

    get home_path(locale: :en)
    assert_select ".hub-menu form[action='/en/packs'][method=post] button.menu-item .menu-item__badge", "10"

    post packs_path(locale: :en)

    pack = Game::Pack.where(player_id: player.id).where.not(opened_at: nil).sole
    assert_redirected_to "/en/packs/#{pack.token}"
    assert_response :see_other
    follow_redirect!
    assert_response :success
    assert_select "h1", "Your pack, Brother"
    assert_select ".card", 0
    assert_select ".toasts > .toast", 0
    assert_not_includes response.body, pack.token
    assert_equal "no-store", response.headers["Cache-Control"]
    assert_select "meta[name=turbo-cache-control][content=no-cache]"

    props = reveal_props
    views = Catalog::CardViews.call(pack.card_season_ids, locale: :en)
    cards = pack.card_season_ids.map { |id| views.fetch(id) }
    assert_equal cards.map { [ it.rarity, it.title ] }, props["cards"].map { it.values_at("rarity", "title") }
    # Each face rendered on the server, at both sizes, with the booster's effects.
    props["cards"].zip(cards).each do |card, view|
      assert_equal %w[m xl], card["faces"].keys
      card["faces"].each do |size, html|
        face = Nokogiri::HTML5.fragment(html)
        assert_equal 1, face.css(".card.card--#{size}.card--booster.card--rarity-#{view.rarity}[data-controller=tilt]").size
        assert_equal view.title, face.at_css(".card__title").text
        assert_empty face.css("[style]")
      end
    end
    assert_equal CardStrings.new.to_props.as_json, props["cardStrings"]
    assert_equal "Flip all", props.dig("strings", "flipAll")
    assert_equal "Previous card", props.dig("strings", "previous")
    assert_equal (1..5).map { |n| "Card #{n} of 5" }, props.dig("strings", "progress")
    assert_equal "/en/packs", props["openPackUrl"]
    assert_equal "/en", props["hubUrl"]
    assert_equal "Back to the bridge", props.dig("strings", "backToHub")
    assert_select ".pack-reveal__fallback a[href='/en']", "Back to the bridge"
    assert_equal "Show my cards", props.dig("strings", "reload")

    get pack_path(pack.token, locale: :en)

    assert_response :success
    assert_nil reveal_props
    assert_not_equal "no-store", response.headers["Cache-Control"]
    assert_select "meta[name=turbo-cache-control]", 0
    assert_equal pack.card_season_ids.map { |id| views.fetch(id).title }, css_select(".pack-result__card .card.card--m .card__title").map(&:text)
    # Each face leads to its card's detail, in its season.
    assert_equal pack.card_season_ids.map { |id| "/en/cards/#{views.fetch(id).id}/seasons/1" },
      css_select(".pack-result__card > a.card-link").map { it["href"] }
    assert_select ".pack-result__card > a.card-link[data-turbo-prefetch=false] > .card.card--m", 5
    assert_select ".pack-result__card .card--booster", 0
    assert_select "[style]", 0
    assert_equal [ "Open the next pack", "Back to the bridge" ], end_buttons

    get home_path(locale: :en)
    assert_equal "9", reserve_badge
  end

  test "the faces are named in the locale of the URL" do
    player = accounts_players(:player)
    legendary = catalog_card_seasons(:legendary_card_one).id
    pack = create_pack(player, cards: [ legendary ] * 5, opened_at: 1.minute.ago)
    sign_in(player.steam_id)

    get pack_path(pack.token, locale: :fr)

    assert_select "h1", "Ton paquet, Confrère"
    assert_equal [ "Couronne d'or" ] * 5, css_select(".card__title").map(&:text)
    assert_equal [ "Légendaire" ] * 5, css_select(".card .card__rarity").map(&:text)
    assert_equal [ "Couronne d'or, Légendaire, saison 1" ] * 5, css_select(".pack-result__card > a.card-link").map { it["aria-label"] }
    assert_equal [ "/fr/cards/golden-crown/seasons/1" ] * 5, css_select(".pack-result__card > a.card-link").map { it["href"] }
  end

  test "the reveal of a pack whose card appears five times keeps the five, in French" do
    player = accounts_players(:player)
    legendary = catalog_card_seasons(:legendary_card_one).id
    create_pack(player, cards: [ legendary ] * 5, available_at: 1.day.ago)
    sign_in(player.steam_id)

    post packs_path(locale: :fr)
    follow_redirect!

    props = reveal_props
    assert_equal [ "Couronne d'or" ] * 5, props["cards"].map { it["title"] }
    assert_equal [ "legendary" ] * 5, props["cards"].map { it["rarity"] }
    assert_equal [ "Légendaire" ] * 5, props["cards"].map { Nokogiri::HTML5.fragment(it.dig("faces", "m")).at_css(".card__rarity").text }
    assert_equal "Tout retourner", props.dig("strings", "flipAll")
    assert_equal "Carte précédente", props.dig("strings", "previous")
    assert_equal "Carte 1 sur 5", props.dig("strings", "progress").first
  end

  test "with no pack left, both branches end on the way back to the hub alone" do
    player = accounts_players(:player)
    pack = create_pack(player, available_at: 1.day.ago)
    sign_in(player.steam_id)

    post packs_path(locale: :en)
    follow_redirect!
    assert_nil reveal_props["openPackUrl"]

    get pack_path(pack.token, locale: :en)
    assert_equal [ "Back to the bridge" ], end_buttons
  end

  test "a daily bonus pack reveals its three cards" do
    player = accounts_players(:player)
    create_pack(player, kind: :bonus, cards: fixture_tier_ids.last(3), available_at: 1.day.ago)
    sign_in(player.steam_id)

    post packs_path(locale: :en)
    follow_redirect!

    assert_select "h1", "Your daily bonus"
    props = reveal_props
    assert_equal %w[rare epic legendary], props["cards"].map { it["rarity"] }
    assert_equal [ "Card 1 of 3", "Card 2 of 3", "Card 3 of 3" ], props.dig("strings", "progress")
  end

  test "the flash's notices and alerts still show, and nothing else of it" do
    sign_in(NEW_STEAM_ID)
    follow_redirect!

    assert_select ".toasts > .toast", 1
    assert_select ".toasts > .toast--notice .toast__message", I18n.t("sessions.create.welcome", locale: :en)
  end

  test "another player's pack, an unopened pack and an unknown token are not found" do
    player = accounts_players(:player)
    foreign = create_pack(accounts_players(:moderator), opened_at: 1.minute.ago)
    unopened = create_pack(player)
    sign_in(player.steam_id)

    [ foreign.token, unopened.token, "unknown-token" ].each do |token|
      get pack_path(token, locale: :en)

      assert_response :not_found, token
    end
  end

  test "a visitor cannot read a pack" do
    pack = create_pack(accounts_players(:player), opened_at: 1.minute.ago)

    get pack_path(pack.token, locale: :en)

    assert_response :not_found
  end

  test "an empty reserve disables menu 01, and opening is refused with an alert" do
    player = accounts_players(:player)
    create_pack(player, available_at: 1.day.from_now)
    sign_in(player.steam_id)

    get home_path(locale: :fr)
    assert_equal "true", open_item["aria-disabled"]
    assert_equal "Réserve vide", open_item.at_css(".visually-hidden").text
    assert_select ".hub-menu form", false

    post packs_path(locale: :fr)

    assert_redirected_to home_path(locale: :fr)
    assert_equal I18n.t("errors.game.no_pack_available", locale: :fr), flash[:alert]
    assert_equal 0, Game::Holding.where(player_id: player.id).count
  end

  test "a visitor's menu 01 opens the sign-in panel, and a visitor's opening is refused; nothing changes" do
    get home_path(locale: :en)
    assert_equal "sign-in-panel", open_item["data-dialog-opener-dialog-value"]
    assert_select ".hub-menu form", false
    assert_select "[data-controller=countdown]", count: 0

    assert_no_difference [ -> { Game::Pack.count }, -> { Game::Pack.where.not(opened_at: nil).count }, -> { Game::Holding.count } ] do
      post packs_path(locale: :en)
    end

    assert_redirected_to home_path(locale: :en)
    assert_equal I18n.t("authorization.sign_in_required", locale: :en), flash[:alert]
  end

  test "more than 30 openings a minute by one player are sent back to the hub with an alert" do
    player = accounts_players(:player)
    31.times { |index| create_pack(player, available_at: (index + 1).minutes.ago) }
    sign_in(player.steam_id)
    with_counting_rate_limit(PacksController) do
      30.times do
        post packs_path(locale: :en)
        assert_response :see_other
        assert_match %r{/en/packs/}, response.location
      end

      post packs_path(locale: :en)
    end

    assert_redirected_to home_path(locale: :en)
    assert_equal I18n.t("packs.create.throttled", locale: :en), flash[:alert]
    assert_equal 1, Game::BankSummary.call(player)[:available]
  end

  # The packs chip's countdown in the top bar.
  def countdown
    css_select(".top-bar .packs-chip__next[data-controller=countdown]")
  end

  test "opening a full bank leaves nine packs and a countdown of ten minutes, read as a time to screen readers" do
    player = accounts_players(:player)
    now = Time.utc(2026, 10, 2, 14, 22)
    travel_to(now) { Game::FillBank.new.call(player:).value! }
    sign_in(player.steam_id)

    travel_to(now) do
      post packs_path(locale: :en)
      get home_path(locale: :en)
    end

    assert_equal "9", reserve_badge
    assert_equal "600", countdown.sole["data-countdown-seconds-value"]
    assert_equal "true", countdown.sole["data-countdown-refresh-value"]
    assert_select ".packs-chip__next [aria-hidden=true]", text: /\+1 in\s+10:00/
    assert_select ".packs-chip__next [data-countdown-target=clock]", "10:00"
    assert_select ".packs-chip__next .visually-hidden", "Next booster at 14:32 (UTC)"
    assert_select "meta[name=turbo-refresh-method][content=morph]"
    assert_select "meta[name=turbo-refresh-scroll][content=preserve]"
    assert_select "meta[name=turbo-cache-control][content=no-cache]"
  end

  test "back 35 minutes after opening all ten packs, the hub shows three and the countdown points to 40 minutes" do
    player = accounts_players(:player)
    now = Time.utc(2026, 10, 2, 9, 0)
    travel_to(now) { Game::FillBank.new.call(player:).value! }
    sign_in(player.steam_id)
    travel_to(now) { 10.times { post packs_path(locale: :fr) } }

    travel_to(now + 35.minutes) { get home_path(locale: :fr) }

    assert_equal "3", reserve_badge
    assert_equal "300", countdown.sole["data-countdown-seconds-value"]
    assert_select ".packs-chip__next [aria-hidden=true]", text: /\+1 dans\s+05:00/
    assert_select ".packs-chip__next .visually-hidden", "Prochain booster à 09:40 (UTC)"
  end

  test "with no pack available now, menu 01 is disabled and the countdown shows" do
    player = accounts_players(:player)
    create_pack(player, available_at: 4.minutes.from_now)
    sign_in(player.steam_id)

    get home_path(locale: :en)

    assert_equal "true", open_item["aria-disabled"]
    assert_equal "0", reserve_badge
    assert_equal 1, countdown.size
  end

  test "a full bank with bonus packs shows no countdown" do
    player = accounts_players(:player)
    Game::FillBank.new.call(player:).value!
    create_pack(player, kind: :bonus)
    create_pack(player, kind: :bonus, available_at: 5.minutes.from_now)
    sign_in(player.steam_id)

    get home_path(locale: :en)

    assert_equal "11", reserve_badge
    assert_empty countdown
    assert_select ".packs-chip__next--full", "Reserve full"
  end

  test "a visitor sees no countdown" do
    create_pack(accounts_players(:player), available_at: 4.minutes.from_now)

    get home_path(locale: :en)

    assert_empty countdown
  end
end

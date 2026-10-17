require "test_helper"
require_relative "../support/counting_rate_limit"
require_relative "../support/game_packs"
require_relative "../support/steam_sign_in"

# Opening a pack (R9, CAP-4): the booster's opening exchange (JSON, AD-23),
# the form the booster screen falls back to without JavaScript, the pack's
# page face up ("my last booster"), and every refusal.
class PacksControllerTest < ActionDispatch::IntegrationTest
  include CountingRateLimit
  include GamePacks
  include SteamSignIn

  NEW_STEAM_ID = "76561197960287930".freeze

  setup do
    Game::DrawPool.reset!
  end

  # Menu 01 of the hub: the link to the booster screen.
  def open_item
    css_select(".hub-menu .menu-item[aria-keyshortcuts='1']").sole
  end

  def reserve_badge
    open_item.at_css(".menu-item__badge").text
  end

  # Any React island on the page (Turbo Mount).
  ISLAND = "[data-controller^=turbo-mount]".freeze

  def end_buttons
    css_select(".pack-end .button").map { |button| button.text.strip }
  end

  test "a new player opens a pack with the form: it lands on the pack's page, face up, on every visit" do
    sign_in_new_player(NEW_STEAM_ID)
    player = Accounts::Player.find_by!(steam_id: NEW_STEAM_ID)

    get home_path(locale: :en)
    assert_select ".hub-menu a.menu-item[href='/en/booster'] .menu-item__badge", "10"

    post packs_path(locale: :en)

    pack = Game::Pack.where(player_id: player.id).where.not(opened_at: nil).sole
    assert_redirected_to "/en/packs/#{pack.token}"
    assert_response :see_other
    follow_redirect!
    assert_response :success
    assert_select "h1", "Your capsule"
    assert_select "ol.pack-result__cards[aria-label=?]", "The cards of your capsule"
    assert_select ".toasts > .toast", 0
    assert_select ISLAND, 0
    assert_not_equal "no-store", response.headers["Cache-Control"]
    assert_select "meta[name=turbo-cache-control]", 0

    views = Catalog::CardViews.call(pack.card_season_ids, locale: :en)
    assert_equal pack.card_season_ids.map { |id| views.fetch(id).title }, css_select(".pack-result__card .card.card--m .card__title").map(&:text)
    # Each face leads to its card's detail, in its season.
    assert_equal pack.card_season_ids.map { |id| "/en/cards/#{views.fetch(id).id}/seasons/1" },
      css_select(".pack-result__card > a.card-link").map { it["href"] }
    assert_select ".pack-result__card > a.card-link[data-turbo-prefetch=false] > .card.card--m", 5
    assert_select ".pack-result__card .card--booster", 0
    assert_select "[style]", 0
    assert_equal [ "Open a capsule", "Back to the bridge" ], end_buttons
    assert_select ".pack-end a.button--primary[href='/en/booster']", "Open a capsule"
    assert_select ".pack-end form", 0

    get pack_path(pack.token, locale: :en)
    assert_response :success
    assert_select ".pack-result__card .card.card--m", 5

    get home_path(locale: :en)
    assert_equal "9", reserve_badge
  end

  test "the faces are named in the locale of the URL" do
    player = accounts_players(:player)
    legendary = catalog_card_seasons(:legendary_card_one).id
    pack = create_pack(player, cards: [ legendary ] * 5, opened_at: 1.minute.ago)
    sign_in(player)

    get pack_path(pack.token, locale: :fr)

    assert_select "h1", "Votre capsule"
    assert_select "ol.pack-result__cards[aria-label=?]", "Les cartes de votre capsule"
    assert_equal [ "Couronne d'or" ] * 5, css_select(".card__title").map(&:text)
    assert_equal [ "Légendaire" ] * 5, css_select(".card .card__rarity").map(&:text)
    assert_equal [ "Couronne d'or, 1998, Légendaire, saison 1" ] * 5, css_select(".pack-result__card > a.card-link").map { it["aria-label"] }
    assert_equal [ "/fr/cards/golden-crown/seasons/1" ] * 5, css_select(".pack-result__card > a.card-link").map { it["href"] }
  end

  test "a pack whose card appears five times answers the five, in French, each with its title, year and spoken label" do
    player = accounts_players(:player)
    legendary = catalog_card_seasons(:legendary_card_one).id
    create_pack(player, cards: [ legendary ] * 5, available_at: 1.day.ago)
    sign_in(player)

    open_json(locale: :fr)

    assert_response :ok
    assert_equal [ "Couronne d'or" ] * 5, body["cards"].map { it["title"] }
    assert_equal [ 1998 ] * 5, body["cards"].map { it["year"] }
    assert_equal [ "Couronne d'or — 1998" ] * 5, body["cards"].map { it["label"] }
    assert_equal [ "legendary" ] * 5, body["cards"].map { it["tier"] }
    assert_equal [ "Légendaire" ] * 5, body["cards"].map { Nokogiri::HTML5.fragment(it.dig("faces", "m")).at_css(".card__rarity").text }
  end

  test "with no pack left, the pack's page ends on the way back to the hub alone" do
    player = accounts_players(:player)
    pack = create_pack(player, available_at: 1.day.ago)
    sign_in(player)

    post packs_path(locale: :en)
    follow_redirect!
    assert_equal [ "Back to the bridge" ], end_buttons

    get pack_path(pack.token, locale: :en)
    assert_equal [ "Back to the bridge" ], end_buttons
  end

  test "the pack's page reads the reserve once, for its end and the packs chip, and never the daily bonus" do
    player = accounts_players(:player)
    pack = create_pack(player, opened_at: 1.minute.ago)
    3.times { create_pack(player) }
    sign_in(player)

    assert_queries_match(/SELECT COUNT\(\*\) FROM "game_packs"/, count: 1) do
      assert_no_queries_match(/game_daily_bonus_claims/) { get pack_path(pack.token, locale: :en) }
    end
    assert_equal [ "Open a capsule", "Back to the bridge" ], end_buttons
    assert_select ".packs-chip__count", "3"
  end

  test "a daily bonus pack opened with the form shows its three cards" do
    player = accounts_players(:player)
    create_pack(player, kind: :bonus, cards: fixture_tier_ids.last(3), available_at: 1.day.ago)
    sign_in(player)

    post packs_path(locale: :en)
    follow_redirect!

    assert_select "h1", "Your daily capsule"
    assert_equal %w[RARE EPIC LEGENDARY], css_select(".pack-result__card .card__rarity").map { it.text.upcase }
    assert_select ISLAND, 0
  end

  test "the flash's notices and alerts still show, and nothing else of it" do
    sign_in(accounts_players(:player), origin: "/en")
    follow_redirect!

    assert_select ".toasts > .toast", 1
    assert_select ".toasts > .toast--notice .toast__message", I18n.t("sessions.create.welcome", locale: :en)
  end

  test "another player's pack, an unopened pack and an unknown token are not found" do
    player = accounts_players(:player)
    foreign = create_pack(accounts_players(:moderator), opened_at: 1.minute.ago)
    unopened = create_pack(player)
    sign_in(player)

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

  test "an empty reserve greys menu 01's badge, and opening is refused back to the booster screen with an alert" do
    player = accounts_players(:player)
    create_pack(player, available_at: 1.day.from_now)
    sign_in(player)

    get home_path(locale: :fr)
    assert_equal "/fr/booster", open_item["href"]
    assert_nil open_item["aria-disabled"]
    assert_equal "0", open_item.at_css(".menu-item__badge.menu-item__badge--zero").text
    assert_equal "Réserve vide", open_item.at_css(".visually-hidden").text
    assert_select ".hub-menu form", false

    post packs_path(locale: :fr)

    # The form is the booster screen's fallback: its refusal goes back there.
    assert_redirected_to booster_path(locale: :fr)
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
    sign_in(player)
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
    sign_in(player)

    travel_to(now) do
      post packs_path(locale: :en)
      get home_path(locale: :en)
    end

    assert_equal "9", reserve_badge
    assert_equal "600", countdown.sole["data-countdown-seconds-value"]
    assert_equal "true", countdown.sole["data-countdown-refresh-value"]
    assert_select ".packs-chip__next [aria-hidden=true]", text: /\+1 in\s+10:00/
    assert_select ".packs-chip__next [data-countdown-target=clock]", "10:00"
    assert_select ".packs-chip__next .visually-hidden", "Next capsule: 2026-10-02 14:32 UTC"
    assert_select ".packs-chip__next .visually-hidden time[datetime='2026-10-02T14:32:00Z'][data-controller=local-time]"
    assert_select "meta[name=turbo-refresh-method][content=morph]"
    assert_select "meta[name=turbo-refresh-scroll][content=preserve]"
    assert_select "meta[name=turbo-cache-control][content=no-cache]"
  end

  test "back 35 minutes after opening all ten packs, the hub shows three and the countdown points to 40 minutes" do
    player = accounts_players(:player)
    now = Time.utc(2026, 10, 2, 9, 0)
    travel_to(now) { Game::FillBank.new.call(player:).value! }
    sign_in(player)
    travel_to(now) { 10.times { post packs_path(locale: :fr) } }

    travel_to(now + 35.minutes) { get home_path(locale: :fr) }

    assert_equal "3", reserve_badge
    assert_equal "300", countdown.sole["data-countdown-seconds-value"]
    assert_select ".packs-chip__next [aria-hidden=true]", text: /\+1 dans\s+05:00/
    assert_select ".packs-chip__next .visually-hidden", "Prochaine capsule : 2026-10-02 09:40 UTC"
    assert_select ".packs-chip__next .visually-hidden time[datetime='2026-10-02T09:40:00Z']"
  end

  test "with no pack available now, menu 01's badge reads 0 and the countdown shows" do
    player = accounts_players(:player)
    create_pack(player, available_at: 4.minutes.from_now)
    sign_in(player)

    get home_path(locale: :en)

    assert_equal "/en/booster", open_item["href"]
    assert_equal "0", reserve_badge
    assert_equal 1, countdown.size
  end

  test "a pack more than an hour away counts down in hours, not in total minutes" do
    player = accounts_players(:player)
    now = Time.utc(2026, 10, 2, 14, 22)
    travel_to(now) { create_pack(player, available_at: now + 90.minutes) }
    sign_in(player)

    travel_to(now) { get home_path(locale: :en) }

    assert_equal "5400", countdown.sole["data-countdown-seconds-value"]
    assert_select ".packs-chip__next [aria-hidden=true]", text: /\+1 in\s+1:30:00/
    assert_select ".packs-chip__next [data-countdown-target=clock]", "1:30:00"
    assert_select ".packs-chip__next .visually-hidden", "Next capsule: 2026-10-02 15:52 UTC"
    assert_select ".packs-chip__next .visually-hidden time[datetime='2026-10-02T15:52:00Z']"
  end

  test "a full bank with bonus packs shows no countdown" do
    player = accounts_players(:player)
    Game::FillBank.new.call(player:).value!
    create_pack(player, kind: :bonus)
    create_pack(player, kind: :bonus, available_at: 5.minutes.from_now)
    sign_in(player)

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

  # --- The booster's opening exchange (JSON, AD-23) -----------------------

  KEY = "3c1f9a2e-7d4b-4c8a-b5e6-0f2d9e8a1b7c".freeze

  def open_json(key = KEY, locale: :en)
    headers = { "Accept" => "application/json" }
    headers["Idempotency-Key"] = key unless key.nil?
    post packs_path(locale:), headers:
  end

  def body = response.parsed_body

  # Every key of a JSON document, at any depth.
  def json_keys(node)
    case node
    when Hash then node.keys + node.values.flat_map { json_keys(it) }
    when Array then node.flat_map { json_keys(it) }
    else []
    end
  end

  # [path, value] of every integer in a JSON document.
  def json_integers(node, path = [])
    case node
    when Hash then node.flat_map { |key, value| json_integers(value, path + [ key ]) }
    when Array then node.flat_map { json_integers(it, path + [ "[]" ]) }
    when Integer then [ [ path.join("."), node ] ]
    else []
    end
  end

  # Everything an opening writes for the player.
  def written(player)
    [ Game::Pack.where(player_id: player.id).order(:id).pluck(:id, :opened_at, :idempotency_key, :card_back),
      Game::Holding.where(player_id: player.id).order(:card_season_id).pluck(:card_season_id, :quantity),
      game_events(player).size ]
  end

  def assert_json_error(status, code, message)
    assert_response status
    assert_equal({ "error" => { "code" => code, "message" => message } }, body)
  end

  test "a JSON opening answers the pack, its cards with their faces, the bank, the server time and the counts before" do
    player = accounts_players(:player)
    now = Time.utc(2026, 10, 6, 14, 22)
    travel_to(now) { Game::FillBank.new.call(player:).value! }
    oldest = Game::Pack.where(player_id: player.id).available(now).first
    counts_before = Game::TierCounts.call(player)
    sign_in(player)

    travel_to(now) { open_json }

    assert_response :ok
    pack = oldest.reload
    assert_predicate pack, :opened?
    assert_equal KEY, pack.idempotency_key
    assert_equal "standard", pack.card_back
    assert_equal [ pack.id ], game_events(player, Game::PackOpened).map { it.data[:pack_id] }

    assert_equal %w[pack cards bank serverTime tierCountsBefore setTiers unlockedCardBacks], body.keys
    assert_equal({ "token" => pack.token, "kind" => "regular", "cardBack" => "standard", "url" => "/en/packs/#{pack.token}" }, body["pack"])
    scheduled = (now + 10.minutes).iso8601(3)
    assert_equal({ "available" => 9, "reserveFull" => false, "nextAvailableAt" => scheduled, "scheduledAt" => [ scheduled ], "nextPackSize" => 5 },
      body["bank"])
    assert_equal "2026-10-06T14:22:00.000Z", body["serverTime"]
    assert_equal counts_before.transform_keys { Catalog::Rarity::TIERS.fetch(it).to_s }, body["tierCountsBefore"]
    assert_equal %w[common uncommon rare epic legendary], body["tierCountsBefore"].keys
    assert_equal [], body["unlockedCardBacks"]

    views = Catalog::CardViews.call(pack.card_season_ids, locale: :en)
    cards = pack.card_season_ids.map { views.fetch(it) }
    assert_equal cards.map { [ it.id, it.season_number, it.rarity, it.image_url, it.title, it.year ] },
      body["cards"].map { it.values_at("slug", "season", "tier", "coverUrl", "title", "year") }
    body["cards"].zip(cards).each do |card, view|
      assert_equal %w[slug season tier coverUrl title year label faces], card.keys
      assert_equal %w[s m xl], card["faces"].keys
      card["faces"].each do |size, html|
        face = Nokogiri::HTML5.fragment(html)
        assert_equal 1, face.css(".card.card--#{size}.card--booster.card--rarity-#{view.rarity}[data-controller=tilt]").size
        assert_equal view.title, face.at_css(".card__title").text
        assert_empty face.css("[style]")
      end
    end

    # No database id (AD-15): no id key, and the only integers are counts.
    assert_empty json_keys(body).grep(/\Aid\z|Id\z/)
    assert_equal [ *Array.new(5) { %w[cards.[].season cards.[].year] }.flatten, "bank.available", "bank.nextPackSize", *%w[common uncommon rare epic legendary].map { "tierCountsBefore.#{it}" },
      *Array.new(body["setTiers"].size) { %w[setTiers.[].required setTiers.[].total] }.flatten ],
      json_integers(body).map(&:first)
  end

  test "a JSON opening answers the set tiers it reached, by set then tier, named in the locale and with no id" do
    player = accounts_players(:player)
    common, uncommon, rare, = fixture_tier_ids
    theme = Catalog::Set.insert_all!([ { season_id: catalog_seasons(:one).id, kind: "theme", key: "roguelike", params: { "theme" => "roguelike" } } ],
      returning: :id).rows.flatten.sole
    Catalog::SetMembership.insert_all!([ common, uncommon, rare ].each_with_index.map { |id, index| { set_id: theme, card_season_id: id, position: index + 1 } })
    Catalog::SetTier.insert_all!({ bronze: 1, silver: 1, gold: 2, complete: 3 }.map { |tier, required| { set_id: theme, tier:, required: } })
    create_pack(player, cards: [ common ] * 5)
    sign_in(player)

    open_json
    first = body["setTiers"]
    open_json

    expected = %w[bronze silver].zip([ 1, 1 ]).map do |tier, required|
      { "kind" => "theme", "key" => "roguelike", "name" => "Roguelike", "tier" => tier, "required" => required, "total" => 3,
        "url" => "/en/library/theme/roguelike" }
    end
    assert_equal expected, first
    assert_equal expected, body["setTiers"]
    assert_equal 2, game_events(player, Game::SetTierReached).size
    assert_empty json_keys(body).grep(/\Aid\z|Id\z/)
  end

  test "a JSON opening that leaves the reserve full and nothing scheduled answers so" do
    player = accounts_players(:player)
    10.times { |index| create_pack(player, available_at: (index + 1).minutes.ago) }
    bonus = create_pack(player, kind: :bonus, available_at: 1.hour.ago)
    sign_in(player)

    open_json

    assert_response :ok
    assert_equal bonus.token, body.dig("pack", "token")
    assert_equal({ "available" => 10, "reserveFull" => true, "nextAvailableAt" => nil, "scheduledAt" => [], "nextPackSize" => 5 }, body["bank"])
  end

  test "the same key again replays the same answer, with nothing opened, even once the reserve is empty" do
    player = accounts_players(:player)
    first = create_pack(player, cards: fixture_tier_ids, available_at: 2.minutes.ago)
    create_pack(player)
    sign_in(player)
    open_json
    answer = body

    assert_no_changes -> { written(player) } do
      open_json
    end
    assert_response :ok
    assert_equal answer.slice("pack", "cards", "tierCountsBefore", "setTiers"), body.slice("pack", "cards", "tierCountsBefore", "setTiers")
    assert_equal [ { "kind" => "studio", "key" => "valve", "name" => "Valve", "tier" => "complete", "required" => 1, "total" => 1,
                     "url" => "/en/library/studio/valve" } ], body["setTiers"]
    assert_equal first.token, body.dig("pack", "token")
    assert_equal %w[common uncommon rare epic legendary], body["cards"].map { it["tier"] }

    open_json(SecureRandom.uuid)
    assert_equal 0, body.dig("bank", "available")
    assert_no_changes -> { written(player) } do
      open_json(KEY.upcase)
    end
    assert_response :ok
    assert_equal answer["cards"], body["cards"]
    assert_equal first.token, body.dig("pack", "token")
    assert_equal 0, body.dig("bank", "available")
  end

  test "replays are not counted by the rate limit, and replay past it; a 31st new key is throttled with Retry-After" do
    player = accounts_players(:player)
    31.times { |index| create_pack(player, available_at: (index + 1).minutes.ago) }
    sign_in(player)
    keys = Array.new(31) { SecureRandom.uuid }

    with_counting_rate_limit(PacksController) do
      keys.first(29).each { open_json(it) }
      first_token = Game::Pack.find_by!(player_id: player.id, idempotency_key: keys.first).token
      3.times do
        open_json(keys.first)
        assert_response :ok
        assert_equal first_token, body.dig("pack", "token")
      end
      open_json(keys[29])
      assert_response :ok

      assert_no_changes -> { written(player) } do
        open_json(keys[30])
      end
      assert_json_error :too_many_requests, "throttled", I18n.t("packs.create.throttled", locale: :en)
      assert_equal "60", response.headers["Retry-After"]

      open_json(keys.first)
      assert_response :ok
      assert_equal first_token, body.dig("pack", "token")
    end
    assert_equal 1, Game::BankSummary.call(player)[:available]
  end

  test "another player's key opens this player's own pack" do
    moderator = accounts_players(:moderator)
    create_pack(moderator)
    Game::OpenPack.new.call(player: moderator, idempotency_key: KEY).value!
    player = accounts_players(:player)
    mine = create_pack(player)
    sign_in(player)

    open_json

    assert_response :ok
    assert_equal mine.token, body.dig("pack", "token")
    assert_equal KEY, mine.reload.idempotency_key
  end

  test "an empty reserve answers 422 no_pack_available and writes nothing" do
    player = accounts_players(:player)
    create_pack(player, available_at: 1.day.from_now)
    sign_in(player)

    assert_no_changes -> { written(player) } do
      open_json(locale: :fr)
    end

    assert_json_error :unprocessable_content, "no_pack_available", I18n.t("errors.game.no_pack_available", locale: :fr)
  end

  test "a visitor's JSON opening answers 401 sign_in_required and writes nothing" do
    create_pack(accounts_players(:player))

    assert_no_difference [ -> { Game::Pack.where.not(opened_at: nil).count }, -> { Game::Holding.count } ] do
      open_json
    end

    assert_json_error :unauthorized, "sign_in_required", I18n.t("authorization.sign_in_required", locale: :en)
  end

  test "a JSON opening without a key, or with one that is not a UUID, answers 400 invalid_idempotency_key" do
    player = accounts_players(:player)
    create_pack(player)
    sign_in(player)

    [ nil, "", "not-a-uuid", KEY.delete("-") ].each do |key|
      assert_no_changes -> { written(player) } do
        open_json(key)
      end
      assert_json_error :bad_request, "invalid_idempotency_key", I18n.t("errors.game.invalid_idempotency_key", locale: :en)
    end
  end

  test "a daily bonus pack answers its three cards, each with its three faces" do
    player = accounts_players(:player)
    create_pack(player, kind: :bonus, cards: fixture_tier_ids.last(3), available_at: 1.day.ago)
    # Portal's main theme, its genre, ends its spoken label.
    Catalog::CardSeason.where(id: catalog_card_seasons(:portal_one).id).update_all(main_theme: "puzzle")
    sign_in(player)

    open_json

    assert_response :ok
    assert_equal "bonus", body.dig("pack", "kind")
    assert_equal %w[rare epic legendary], body["cards"].map { it["tier"] }
    # Spoken as the booster's live region says them: title — publisher, year, genre.
    assert_equal [ "Blue Depths — 2014", "Portal — Valve, 2007, Puzzle", "Golden Crown — 1998" ], body["cards"].map { it["label"] }
    # Nothing left to open: no next pack size.
    assert_nil body.dig("bank", "nextPackSize")
    body["cards"].each do |card|
      assert_equal %w[s m xl], card["faces"].keys
      card["faces"].each { |size, html| assert_equal 1, Nokogiri::HTML5.fragment(html).css(".card.card--#{size}.card--booster").size }
    end
  end

  test "the form's opening keeps the standard card back and no key" do
    player = accounts_players(:player)
    pack = create_pack(player)
    sign_in(player)

    post packs_path(locale: :en)

    assert_redirected_to "/en/packs/#{pack.token}"
    assert_equal [ nil, "standard" ], [ pack.reload.idempotency_key, pack.card_back ]
  end

  test "the pack's page after a JSON opening shows the cards face up, without the reveal" do
    player = accounts_players(:player)
    create_pack(player)
    sign_in(player)
    open_json

    get body.dig("pack", "url")

    assert_response :success
    assert_select ISLAND, 0
    assert_select ".pack-result__card .card.card--m", 5
  end
end

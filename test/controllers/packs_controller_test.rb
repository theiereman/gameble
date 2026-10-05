require "test_helper"
require_relative "../support/counting_rate_limit"
require_relative "../support/game_packs"

# The attic chest and the pack result page (R9, CAP-4): opening a pack end to
# end, the result page, and every refusal.
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

  def chest_button
    css_select(".attic__object--chest .attic__chest-action button").sole
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
    assert_select ".attic__object--chest form[action='/en/packs'][method=post] button", "Open a pack (10)"

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
    assert_equal pack.card_season_ids.map { |id| views.fetch(id).to_props.as_json }, props["cards"]
    assert_equal CardStrings.for(views.values).to_props.as_json, props["cardStrings"]
    assert_equal "Flip all", props.dig("strings", "flipAll")
    assert_equal "Previous card", props.dig("strings", "previous")
    assert_equal (1..5).map { |n| "Card #{n} of 5" }, props.dig("strings", "progress")
    assert_equal "/en/packs", props["openPackUrl"]
    assert_equal "/en", props["atticUrl"]
    assert_select ".pack-reveal__fallback a[href='/en']", "Back to the attic"
    assert_equal "Show my cards", props.dig("strings", "reload")

    get pack_path(pack.token, locale: :en)

    assert_response :success
    assert_nil reveal_props
    assert_not_equal "no-store", response.headers["Cache-Control"]
    assert_select "meta[name=turbo-cache-control]", 0
    assert_equal pack.card_season_ids.map { |id| views.fetch(id).title }, css_select(".pack-result__card .card--face .card__title").map(&:text)
    # Each face leads to its card's detail, in its season.
    assert_equal pack.card_season_ids.map { |id| "/en/cards/#{views.fetch(id).id}/seasons/1" },
      css_select(".pack-result__card > a.card-link").map { it["href"] }
    assert_select ".pack-result__card > a.card-link[data-turbo-prefetch=false] > .card--face", 5
    assert_equal [ "Open the next pack", "Back to the attic" ], end_buttons

    get home_path(locale: :en)
    assert_equal "Open a pack (9)", chest_button.text
  end

  test "the faces are named in the locale of the URL" do
    player = accounts_players(:player)
    gold = catalog_card_seasons(:gold_card_one).id
    pack = create_pack(player, cards: [ gold ] * 5, opened_at: 1.minute.ago)
    sign_in(player.steam_id)

    get pack_path(pack.token, locale: :fr)

    assert_select "h1", "Ton paquet, Confrère"
    assert_equal [ "Couronne d'or" ] * 5, css_select(".card__title").map(&:text)
    assert_equal [ "Or" ] * 5, css_select(".card--face .card__plate > .visually-hidden").map(&:text)
    assert_equal [ "Couronne d'or, Or, saison 1" ] * 5, css_select(".pack-result__card > a.card-link").map { it["aria-label"] }
    assert_equal [ "/fr/cards/golden-crown/seasons/1" ] * 5, css_select(".pack-result__card > a.card-link").map { it["href"] }
  end

  test "the reveal of a pack whose card appears five times keeps the five, in French" do
    player = accounts_players(:player)
    gold = catalog_card_seasons(:gold_card_one).id
    create_pack(player, cards: [ gold ] * 5, available_at: 1.day.ago)
    sign_in(player.steam_id)

    post packs_path(locale: :fr)
    follow_redirect!

    props = reveal_props
    assert_equal [ "Couronne d'or" ] * 5, props["cards"].map { it["title"] }
    assert_equal [ "golden-crown" ] * 5, props["cards"].map { it["id"] }
    assert_equal "Tout retourner", props.dig("strings", "flipAll")
    assert_equal "Carte précédente", props.dig("strings", "previous")
    assert_equal "Carte 1 sur 5", props.dig("strings", "progress").first
  end

  test "with no pack left, both branches end on the attic alone" do
    player = accounts_players(:player)
    pack = create_pack(player, available_at: 1.day.ago)
    sign_in(player.steam_id)

    post packs_path(locale: :en)
    follow_redirect!
    assert_nil reveal_props["openPackUrl"]

    get pack_path(pack.token, locale: :en)
    assert_equal [ "Back to the attic" ], end_buttons
  end

  test "a daily bonus pack reveals its three cards" do
    player = accounts_players(:player)
    create_pack(player, kind: :bonus, cards: fixture_tier_ids.last(3), available_at: 1.day.ago)
    sign_in(player.steam_id)

    post packs_path(locale: :en)
    follow_redirect!

    assert_select "h1", "Your daily bonus"
    props = reveal_props
    assert_equal %w[sapphire amethyst gold], props["cards"].map { it["rarity"] }
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

  test "an empty chest shows a disabled button, and opening is refused with an alert" do
    player = accounts_players(:player)
    create_pack(player, available_at: 1.day.from_now)
    sign_in(player.steam_id)

    get home_path(locale: :fr)
    assert_equal "Aucun paquet", chest_button.text
    assert chest_button["disabled"]
    assert_select ".attic__object--chest form", false

    post packs_path(locale: :fr)

    assert_redirected_to home_path(locale: :fr)
    assert_equal I18n.t("errors.game.no_pack_available", locale: :fr), flash[:alert]
    assert_equal 0, Game::Holding.where(player_id: player.id).count
  end

  test "a visitor's chest button starts the Steam sign-in, and a visitor's opening is refused; nothing changes" do
    get home_path(locale: :en)
    assert_select ".attic__object--chest form[action='/auth/steam'][method=post] button", "Enlist through Steam to open a pack"
    assert_select ".attic__object--chest form[action='/auth/steam'] input[name=origin][value='/en']"
    assert_select ".attic__countdown", count: 0

    assert_no_difference [ -> { Game::Pack.count }, -> { Game::Pack.where.not(opened_at: nil).count }, -> { Game::Holding.count } ] do
      post packs_path(locale: :en)
    end

    assert_redirected_to home_path(locale: :en)
    assert_equal I18n.t("authorization.sign_in_required", locale: :en), flash[:alert]
  end

  test "more than 30 openings a minute by one player are sent back to the attic with an alert" do
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

  def countdown
    css_select(".attic__object--chest .attic__countdown[data-controller=countdown]")
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

    assert_equal "Open a pack (9)", chest_button.text
    assert_equal "600", countdown.sole["data-countdown-seconds-value"]
    assert_select ".attic__countdown [aria-hidden=true]", text: /Next pack in\s+10:00/
    assert_select ".attic__countdown [data-countdown-target=clock]", "10:00"
    assert_select ".attic__countdown .visually-hidden", "Next pack at 14:32 (UTC)"
    assert_select "meta[name=turbo-refresh-method][content=morph]"
    assert_select "meta[name=turbo-refresh-scroll][content=preserve]"
    assert_select "meta[name=turbo-cache-control][content=no-cache]"
  end

  test "back 35 minutes after opening all ten packs, the chest shows three and the countdown points to 40 minutes" do
    player = accounts_players(:player)
    now = Time.utc(2026, 10, 2, 9, 0)
    travel_to(now) { Game::FillBank.new.call(player:).value! }
    sign_in(player.steam_id)
    travel_to(now) { 10.times { post packs_path(locale: :fr) } }

    travel_to(now + 35.minutes) { get home_path(locale: :fr) }

    assert_equal "Ouvrir un paquet (3)", chest_button.text
    assert_equal "300", countdown.sole["data-countdown-seconds-value"]
    assert_select ".attic__countdown [aria-hidden=true]", text: /Prochain paquet dans\s+05:00/
    assert_select ".attic__countdown .visually-hidden", "Prochain paquet à 09:40 (UTC)"
  end

  test "with no pack available now, the chest is disabled and the countdown shows" do
    player = accounts_players(:player)
    create_pack(player, available_at: 4.minutes.from_now)
    sign_in(player.steam_id)

    get home_path(locale: :en)

    assert_equal "No pack", chest_button.text
    assert chest_button["disabled"]
    assert_equal 1, countdown.size
  end

  test "a full bank with bonus packs shows no countdown" do
    player = accounts_players(:player)
    Game::FillBank.new.call(player:).value!
    create_pack(player, kind: :bonus)
    create_pack(player, kind: :bonus, available_at: 5.minutes.from_now)
    sign_in(player.steam_id)

    get home_path(locale: :en)

    assert_equal "Open a pack (11)", chest_button.text
    assert_empty countdown
  end

  test "a visitor sees no countdown" do
    create_pack(accounts_players(:player), available_at: 4.minutes.from_now)

    get home_path(locale: :en)

    assert_empty countdown
  end
end

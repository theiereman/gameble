require "test_helper"
require_relative "../support/game_packs"
require_relative "../support/steam_sign_in"

# The booster screen (EXPERIENCE.md, Ouverture de booster): the Booster
# island with its props, an opened pack shown again, the booster top bar,
# the no-JavaScript fallback, the bank in JSON, and the visitor's refusal.
class BoostersControllerTest < ActionDispatch::IntegrationTest
  include GamePacks
  include SteamSignIn

  ISLAND = "[data-controller=turbo-mount-booster][data-turbo-mount-booster-component-value=Booster]".freeze

  setup do
    @player = accounts_players(:player)
  end

  def props
    JSON.parse(css_select(ISLAND).sole["data-turbo-mount-booster-props-value"])
  end

  # Every key of a JSON document, at any depth.
  def json_keys(node)
    case node
    when Hash then node.keys + node.values.flat_map { json_keys(it) }
    when Array then node.flat_map { json_keys(it) }
    else []
    end
  end

  test "a visitor is sent to the hub and asked to sign in" do
    get booster_path(locale: :en)

    assert_redirected_to home_path(locale: :en)
    assert_equal I18n.t("authorization.sign_in_required", locale: :en), flash[:alert]
  end

  test "a player gets the island with the bank, the season and every word, and the booster top bar" do
    now = Time.utc(2026, 10, 6, 14, 22)
    travel_to(now) { Game::FillBank.new.call(player: @player).value! }
    travel_to(now) { Game::OpenPack.new.call(player: @player).value! }
    sign_in(@player)

    travel_to(now) { get booster_path(locale: :en) }

    assert_response :success
    assert_select "title", "Capsule opening"
    assert_select "main h1.visually-hidden", "Capsule opening"
    assert_select ".top-bar .top-bar__title", "Capsule opening"
    assert_select "meta[name=turbo-cache-control][content=no-cache]"
    assert_select "[style]", 0

    data = props
    assert_equal "/en/packs", data["openUrl"]
    assert_equal "/en", data["hubUrl"]
    assert_equal "/en/cards/SLUG", data["cardUrl"]
    assert_equal "/en/cards/SLUG/seasons/NUMBER/repost", data["repostUrl"]
    assert_equal "/en/booster.json", data["bankUrl"]
    assert_equal ",", data["delimiter"]
    assert_equal 1, data["season"]
    assert_equal 5, data["packSize"]
    assert_equal({ "available" => 9, "reserveFull" => false, "nextAvailableAt" => "2026-10-06T14:32:00.000Z", "serverTime" => "2026-10-06T14:22:00.000Z",
      "nextPackSize" => 5 }, data["bank"])
    assert_equal({ "common" => "Common", "uncommon" => "Uncommon", "rare" => "Rare", "epic" => "Epic", "legendary" => "Legendary" }, data["rarityNames"])
    assert_equal %w[common uncommon rare epic legendary], data["rarityIcons"].keys
    assert_equal({ "width" => 109, "height" => 112 }, data["artPalette"])
    assert_equal %w[previous next], data["arrowIcons"].keys
    data["arrowIcons"].each_value { |svg| assert_equal 1, Nokogiri::HTML5.fragment(svg).css("svg.pixel-icon.booster-zoom__nav-icon[aria-hidden=true]").size }
    assert_nil data.fetch("opened")
    data["rarityIcons"].each_value { |svg| assert_equal 1, Nokogiri::HTML5.fragment(svg).css("svg.pixel-icon.booster-card__label-icon[aria-hidden=true]").size }

    strings = data["strings"]
    assert_equal "Open the capsule", strings["open"]
    assert_equal "Reveal all", strings["revealAll"]
    assert_equal "Legendary signal", strings.dig("states", "legendarySignal")
    assert_equal({ "one" => "%{n} capsule", "other" => "%{n} capsules" }, strings["reserveCount"])
    assert_equal "Card %{position} of %{total}, face down. Reveal.", strings["faceDown"]
    assert_equal [ "Previous card", "Next card" ], strings.values_at("zoomPrevious", "zoomNext")
    assert_equal I18n.t("boosters.island", locale: :en).keys.map { it.to_s.camelize(:lower) }.sort, strings.keys.sort
    # No database id (AD-15).
    assert_empty json_keys(data).grep(/\Aid\z|Id\z/)

    # The top bar: back, title, rarity counter and the static reserve chip, no packs chip link.
    assert_select ".top-bar .top-bar__start[data-controller=navigation-lock] a.button[href='/en']"
    assert_select ".top-bar .rarity-counter[data-controller=rarity-counter][data-rarity-counter-delimiter-value=',']"
    assert_select ".top-bar .rarity-counter__count[data-rarity-counter-target=count][data-tier]", 5
    assert_equal %w[common uncommon rare epic legendary], css_select(".top-bar .rarity-counter__count").map { it["data-tier"] }
    assert_select ".top-bar .rarity-legend__count[data-rarity-counter-target=count][data-tier]", 5
    assert_select ".top-bar p.packs-chip.packs-chip--static[data-controller=reserve-chip]" do
      assert_select ".packs-chip__count[data-reserve-chip-target=count]", "9"
      assert_select ".packs-chip__label[data-reserve-chip-target=label]", "in reserve"
    end
    chip = css_select(".packs-chip--static").sole
    assert_equal({ "one" => "%{number} in reserve", "other" => "%{number} in reserve" }, JSON.parse(chip["data-reserve-chip-templates-value"]))
    assert_select ".top-bar a.packs-chip", 0
    assert_select ".tab-bar[data-controller=navigation-lock] a.tab-bar__tab[href='/en/booster'][aria-current=page]"

    # Without JavaScript, the form and the way back; hidden once the island draws.
    assert_select ".booster-island + .booster__fallback" do
      assert_select "form[action='/en/packs'][method=post] button.button--primary", "Open the capsule"
      assert_select "a.button--secondary[href='/en']", "Back to the bridge"
    end
  end

  test "in JSON, a player gets the bank alone, as the island's props carry it, and nothing is written" do
    now = Time.utc(2026, 10, 6, 14, 22)
    travel_to(now) { Game::FillBank.new.call(player: @player).value! }
    travel_to(now) { Game::OpenPack.new.call(player: @player).value! }
    sign_in(@player)

    assert_no_difference -> { Game::Pack.where(player_id: @player.id, opened_at: nil).count } do
      travel_to(now + 4.minutes) { get booster_path(locale: :en, format: :json) }
    end

    assert_response :success
    assert_equal "application/json", response.media_type
    assert_equal({ "bank" => { "available" => 9, "reserveFull" => false, "nextAvailableAt" => "2026-10-06T14:32:00.000Z",
      "serverTime" => "2026-10-06T14:26:00.000Z", "nextPackSize" => 5 } }, response.parsed_body)
    assert_empty json_keys(response.parsed_body).grep(/\Aid\z|Id\z/)
  end

  test "in JSON, a visitor is refused and asked to sign in" do
    get booster_path(locale: :en, format: :json)

    assert_response :unauthorized
    assert_equal({ "error" => { "code" => "sign_in_required", "message" => I18n.t("authorization.sign_in_required", locale: :en) } }, response.parsed_body)
  end

  test "without a published season, the island gets no season number and the fallback stays" do
    create_pack(@player, available_at: 1.hour.ago)
    catalog_seasons(:one).update_columns(status: "draft", published_at: nil)
    sign_in(@player)

    get booster_path(locale: :en)

    assert_response :success
    assert_nil props.fetch("season")
    assert_equal "Capsule", props.dig("strings", "kickerPlain")
    assert_equal "Open the capsule, grand catalogue, %{count} cards", props.dig("strings", "canisterLabelPlain")
    assert_select ".booster__fallback form[action='/en/packs'] button", "Open the capsule"
    assert_select ".booster__fallback a[href='/en']", "Back to the bridge"
  end

  test "an empty reserve: no form in the fallback, the island told so, in French with its delimiter" do
    create_pack(@player, available_at: 1.day.from_now)
    sign_in(@player)

    get booster_path(locale: :fr)

    assert_response :success
    data = props
    assert_equal 0, data.dig("bank", "available")
    assert_equal " ", data["delimiter"]
    assert_equal "Ouvrir la capsule", data.dig("strings", "open")
    assert_equal "Réserve vide", data.dig("strings", "reserveEmpty")
    assert_equal "/fr/cards/SLUG", data["cardUrl"]
    assert_select ".booster__fallback form", 0
    assert_select ".booster__fallback a[href='/fr']", "Retour au pont"
    assert_select ".packs-chip--static .packs-chip__label", "en réserve"
  end

  test "a daily bonus pack first in line: the island is told the next booster holds three cards" do
    create_pack(@player, kind: :bonus, available_at: 2.hours.ago)
    create_pack(@player, available_at: 1.hour.ago)
    sign_in(@player)

    get booster_path(locale: :en)

    assert_response :success
    assert_equal 3, props.dig("bank", "nextPackSize")
    assert_equal 5, props["packSize"]
  end

  test "given one of the player's opened packs, the island is told to show it: its cards in drawn order, the current bank" do
    pack = create_pack(@player, cards: fixture_tier_ids, opened_at: 1.minute.ago)
    create_pack(@player, available_at: 1.hour.ago)
    sign_in(@player)

    assert_no_difference -> { Game::Pack.where(player_id: @player.id, opened_at: nil).count } do
      get booster_path(locale: :fr, pack: pack.token)
    end

    assert_response :success
    assert_select "meta[name=turbo-cache-control][content=no-cache]"
    opened = props.fetch("opened")
    assert_equal({ "token" => pack.token, "kind" => "regular", "cardBack" => "standard", "url" => "/fr/packs/#{pack.token}" }, opened["pack"])
    assert_equal %w[tin-soldier green-hills blue-depths portal golden-crown], opened["cards"].map { it["slug"] }
    assert_equal "Soldat de plomb", opened["cards"].first["title"]
    assert_equal %w[s m xl], opened["cards"].first["faces"].keys
    assert_equal 1, props.dig("bank", "available")
    assert_empty json_keys(props).grep(/\Aid\z|Id\z/)
    assert_select ".booster__fallback form[action='/fr/packs']"
  end

  test "a pack shown again after a new season is published keeps each card's own season" do
    pack = create_pack(@player, cards: fixture_tier_ids, opened_at: 1.minute.ago)
    Catalog::Season.create!(status: :published, number: 2, published_at: Time.current)
    sign_in(@player)

    get booster_path(locale: :en, pack: pack.token)

    assert_response :success
    assert_equal 2, props["season"]
    assert_equal [ 1 ] * 5, props.dig("opened", "cards").map { it["season"] }
  end

  test "another player's pack, one not opened or an unknown token shows the canister as without one" do
    foreign = create_pack(accounts_players(:moderator), cards: fixture_tier_ids, opened_at: 1.minute.ago)
    sealed = create_pack(@player, available_at: 1.hour.ago)
    sign_in(@player)

    [ foreign.token, sealed.token, "nope", "" ].each do |token|
      get booster_path(locale: :en, pack: token)

      assert_response :success, token
      assert_nil props.fetch("opened"), token
      assert_equal 1, props.dig("bank", "available"), token
    end
    get booster_path(locale: :en, pack: [ foreign.token ])
    assert_nil props.fetch("opened")
  end
end

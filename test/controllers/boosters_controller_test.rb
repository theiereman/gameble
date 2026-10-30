require "test_helper"
require_relative "../support/game_packs"
require_relative "../support/game_sets"
require_relative "../support/steam_sign_in"

# The booster screen: the `booster` root controller's markup and values,
# an opened pack shown again, the booster top bar, the no-JavaScript
# fallback, the bank in JSON, and the visitor's refusal.
class BoostersControllerTest < ActionDispatch::IntegrationTest
  include GamePacks
  include GameSets
  include SteamSignIn

  ROOT = "section#booster.booster[data-controller=booster]".freeze

  setup do
    @player = accounts_players(:player)
  end

  def root
    css_select(ROOT).sole
  end

  def value(name)
    root["data-booster-#{name}-value"]
  end

  def strings
    JSON.parse(value("strings"))
  end

  def bank_value(name)
    JSON.parse(value("bank")).fetch(name)
  end

  def opened(name)
    css_select("#{ROOT} template[data-booster-target=#{name}]")
  end

  def fragment(selector)
    Nokogiri::HTML5.fragment(css_select(selector).sole.inner_html)
  end

  # Attribute names that would carry a database id (`data-id`, `data-pack-id`…), in the root and its templates.
  def id_attributes
    nodes = css_select("#{ROOT}, #{ROOT} *").to_a + css_select("#{ROOT} template").flat_map { Nokogiri::HTML5.fragment(it.inner_html).css("*").to_a }
    nodes.flat_map { it.attributes.keys }.grep(/-id\z/)
  end

  # Two sets the opened `pack` reached a tier of: a ranked theme (expert)
  # and a metal theme (bronze), both of ten cards.
  def reach_set_tiers(pack)
    members = fixture_tier_ids + unheld_cards(5)
    reached = { insert_ranked_theme(members, key: "roguelike", season: catalog_seasons(:one)) => "expert",
                insert_theme(members, key: "horror", season: catalog_seasons(:one)) => "bronze" }
    reached.each do |set_id, tier|
      Game::SetTier.create!(player_id: @player.id, set_id:, tier:, reached_by: "pack", pack_id: pack.id, reached_at: Time.current, held: 5)
    end
  end

  # Every key of a JSON document, at any depth.
  def json_keys(node)
    case node
    when Hash then node.keys + node.values.flat_map { json_keys(it) }
    when Array then node.flat_map { json_keys(it) }
    else []
    end
  end

  test "the French counts say the same at zero as at one" do
    %w[hint_remaining hint_done summary canister_facts].each do |key|
      plural = I18n.t("booster.strings.#{key}", locale: :fr)
      assert_equal plural[:one], plural[:zero], key
    end
  end

  test "a visitor is sent to the landing" do
    get booster_path(locale: :en)

    assert_redirected_to home_path(locale: :en)
    assert_nil flash[:alert]
  end

  test "a player gets the screen with the bank, the season and every word, and the booster top bar" do
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

    assert_equal "booster-panel-title", root["aria-labelledby"]
    assert_equal "/en/packs", value("open-url")
    assert_equal "/en/cards/SLUG", value("card-url")
    assert_equal "/en/cards/SLUG/seasons/NUMBER/repost", value("repost-url")
    assert_equal "/en/booster.json", value("bank-url")
    assert_equal ",", value("delimiter")
    assert_equal [ "1", "5" ], [ value("season"), value("pack-size") ]
    assert_equal [ 9, false, "2026-10-06T14:32:00.000Z", "2026-10-06T14:22:00.000Z", 5 ],
      %w[available reserveFull nextAvailableAt serverTime nextPackSize].map { bank_value(it) }
    BoostersHelper::BOOSTER_ACTIONS.each do |child, events|
      events.each { |event, method| assert_includes root["data-action"].split, "#{child}:#{event}->booster##{method}" }
      assert_select "#{ROOT} [data-controller=#{child}]"
      assert_equal "#booster [data-controller~='#{child}']", root["data-booster-#{child}-outlet"]
    end
    assert_select "#{ROOT} [data-controller=booster-info]", 2
    assert_equal "#booster [data-controller~='booster-info']", root["data-booster-booster-info-outlet"]
    assert_select "#{ROOT} .booster-tray[data-booster-tray-palette-width-value='109'][data-booster-tray-palette-height-value='112']"
    assert_select "#{ROOT} [data-controller=booster-celebration]", 2
    assert_select "#{ROOT} template[data-booster-target=pack]", 0

    # The panel and the strip: the season, the title, the reserve and every state word.
    assert_select "#{ROOT} .booster__info" do
      assert_select ".booster__kicker", "Capsule · Season 1"
      assert_select "h2#booster-panel-title", "Grand catalogue"
      assert_select ".booster__value", "5"
      assert_select ".booster__value--reserve", "9 capsules"
      assert_select ".booster__pip", 10
      assert_select ".booster__pip[data-lit]", 9
      assert_select ".booster__state-word span[data-status]", 7
      assert_select ".booster__state-word span[data-status=legendarySignal]", "Legendary signal"
    end
    assert_select "#{ROOT} .booster-strip h2#booster-title", "Season 1 · Grand catalogue"
    assert_select "#{ROOT} .booster__actions button.booster__open", "Open the capsuleOpen the next oneReserve empty"
    assert_select "#{ROOT} .booster__actions button.booster__reveal-all[disabled]", "Reveal all"
    assert_select "#{ROOT} .booster__actions a", 0

    # The canister, its words and the card a pack deals, cloned by the controllers.
    assert_select "#{ROOT} template[data-booster-canister-target=canister]"
    canister = Nokogiri::HTML5.fragment(css_select("#{ROOT} template[data-booster-canister-target=canister]").sole.inner_html)
    assert_equal "Open the capsule Season 1, grand catalogue, 5 cards", canister.at_css("button.booster-canister")["aria-label"]
    assert_select "#{ROOT} .booster__canister-facts", "5 cards"
    assert_select "#{ROOT} template[data-booster-stage-target=card]"
    assert_select "#{ROOT} dialog.booster-zoom[aria-labelledby=booster-zoom-title]"

    # Each tier's name, label and icon.
    rarities = css_select("#{ROOT} template[data-booster-target=rarity]")
    assert_equal %w[common uncommon rare epic legendary], rarities.map { it["data-tier"] }
    assert_equal %w[Common Uncommon Rare Epic Legendary], rarities.map { it["data-name"] }
    assert_equal "Legendary!", rarities.last["data-label"]
    rarities.each { assert_equal 1, Nokogiri::HTML5.fragment(it.inner_html).css("svg.pixel-icon.booster-card__label-icon[aria-hidden=true]").size }

    # The celebration's icons, with each rank's mark.
    assert_select "#{ROOT} template[data-booster-celebration-target=rank]", 10
    ranks = css_select("#{ROOT} .booster__info template[data-booster-celebration-target=rank]")
    assert_equal %w[novice apprentice adept expert master], ranks.map { it["data-rank"] }
    ranks.each do |rank|
      assert_equal 1, Nokogiri::HTML5.fragment(rank.inner_html).css("svg.rank-mark.rank-mark--#{rank["data-rank"]}:not(.rank-mark--fine)").size
    end
    folded = fragment("#{ROOT} .booster__info template[data-booster-celebration-target=folded]")
    assert_equal "/en/library", folded.at_css("a.booster-celebration__banner")["href"]
    assert folded.at_css(".booster-celebration__hint .booster-celebration__icon-wrap svg.pixel-icon.booster-celebration__icon")
    result = fragment("#{ROOT} .booster__info template[data-booster-celebration-target=result]")
    assert result.at_css(".booster-celebration__icon-wrap.booster-celebration__hint--arrow svg.pixel-icon.booster-celebration__icon[aria-hidden=true]")
    phone_result = fragment("#{ROOT} .booster-plate-band template[data-booster-celebration-target=result]")
    assert phone_result.at_css(".booster-celebration__icon-wrap.booster-celebration__arrow svg.pixel-icon.booster-celebration__icon")
    step = fragment("#{ROOT} .booster-plate-band template[data-booster-celebration-target=step]")
    assert_equal "Next result", step.at_css("button.booster-celebration__next")["aria-label"]
    assert step.at_css("button.booster-celebration__next svg.pixel-icon.booster-celebration__icon")
    check = fragment("#{ROOT} .booster__info template[data-booster-celebration-target=check]")
    assert check.at_css(".booster-celebration__icon-wrap.booster-celebration__check svg.pixel-icon.booster-celebration__icon")

    # The zoom's arrows.
    assert_select "#{ROOT} dialog.booster-zoom .booster-zoom__nav svg.pixel-icon.booster-zoom__nav-icon[aria-hidden=true]", 2
    assert_equal [ "Previous card", "Next card" ], css_select("#{ROOT} .booster-zoom__nav").map { it["aria-label"] }

    # No database id.
    assert_empty id_attributes

    # The run-time templates, each a word of booster.strings.
    assert_equal "Card %{position} of %{total}, face down. Reveal.", strings["faceDown"]
    assert_equal({ "one" => "%{n} capsule", "other" => "%{n} capsules" }, strings["reserveCount"])
    assert_equal [ "%{tier} TIER", "SET COMPLETE", "Next result" ], strings["celebration"].values_at("tierTitle", "completeTitle", "next")
    assert_equal({ "bronze" => "BRONZE", "silver" => "SILVER", "gold" => "GOLD", "novice" => "NOVICE", "apprentice" => "APPRENTICE",
      "adept" => "ADEPT", "expert" => "EXPERT", "master" => "MASTER", "complete" => "COMPLETE" }, strings.dig("celebration", "tiers"))
    assert_equal "%{tier} tier reached: %{set}, %{owned} cards out of %{total}.", strings.dig("celebration", "announceTier")
    assert_equal I18n.t("booster.strings", locale: :en).keys.map { it.to_s.camelize(:lower) }.sort, strings.keys.sort

    # The top bar: back, title, rarity counter and the static reserve chip, no packs chip link.
    assert_select ".top-bar .top-bar__start[data-controller=navigation-lock] a.button[href='/en']"
    assert_select ".top-bar .rarity-counter[data-controller=rarity-counter][data-rarity-counter-delimiter-value=',']"
    assert_select ".top-bar .rarity-counter__count[data-rarity-counter-target=count][data-tier]", 5
    assert_equal %w[common uncommon rare epic legendary], css_select(".top-bar .rarity-counter__count").map { it["data-tier"] }
    assert_select ".top-bar #rarity-legend tbody tr", 5
    assert_select ".top-bar #rarity-legend [data-rarity-counter-target]", false
    assert_select ".top-bar .packs-chips[data-controller=reserve-chip] p.packs-chip--static" do
      assert_select ".packs-chip__count[data-reserve-chip-target=count]", "9"
      assert_select ".packs-chip__label[data-reserve-chip-target=label]", "in reserve"
    end
    chip = css_select(".packs-chips").sole
    assert_equal({ "one" => "%{number} in reserve", "other" => "%{number} in reserve" }, JSON.parse(chip["data-reserve-chip-templates-value"]))
    assert_select ".top-bar a.packs-chip", 0
    assert_select ".tab-bar[data-controller=navigation-lock] a.tab-bar__tab[href='/en/booster'][aria-current=page]"

    # Without JavaScript, the form and the way back; hidden once the screen draws.
    assert_select "#{ROOT} + .booster__fallback" do
      assert_select "form[action='/en/packs'][method=post] button.button--primary", "Open the capsule"
      assert_select "a", 0
    end
  end

  test "in JSON, a player gets the bank alone, as the root's values carry it, and nothing is written" do
    now = Time.utc(2026, 10, 6, 14, 22)
    travel_to(now) { Game::FillBank.new.call(player: @player).value! }
    travel_to(now) { Game::OpenPack.new.call(player: @player).value! }
    sign_in(@player)

    assert_no_difference -> { Game::Pack.where(player_id: @player.id, opened_at: nil).count } do
      travel_to(now + 4.minutes) { get booster_path(locale: :en, format: :json) }
    end

    assert_response :success
    assert_equal "application/json", response.media_type
    assert_equal({ "bank" => { "available" => 9, "special" => 0, "openable" => 9, "reserveFull" => false, "nextSpecialKind" => nil, "nextAvailableAt" => "2026-10-06T14:32:00.000Z",
      "serverTime" => "2026-10-06T14:26:00.000Z", "nextPackSize" => 5 } }, response.parsed_body)
    assert_empty json_keys(response.parsed_body).grep(/\Aid\z|Id\z/)
  end

  test "in JSON, a visitor is refused and asked to sign in" do
    get booster_path(locale: :en, format: :json)

    assert_response :unauthorized
    assert_equal({ "error" => { "code" => "sign_in_required", "message" => I18n.t("authorization.sign_in_required", locale: :en) } }, response.parsed_body)
  end

  test "without a published season, the screen gets no season number nor repost, and the fallback stays" do
    create_pack(@player, available_at: 1.hour.ago)
    catalog_seasons(:one).update_columns(status: "draft", published_at: nil)
    sign_in(@player)

    get booster_path(locale: :en)

    assert_response :success
    assert_equal [ "0", "" ], [ value("season"), value("repost-url") ]
    assert_select "#{ROOT} .booster__kicker", "Capsule"
    assert_select "#{ROOT} .booster-strip h2#booster-title", "Grand catalogue"
    canister = Nokogiri::HTML5.fragment(css_select("#{ROOT} template[data-booster-canister-target=canister]").sole.inner_html)
    assert_equal "Open the capsule, grand catalogue, 5 cards", canister.at_css("button.booster-canister")["aria-label"]
    assert_nil canister.at_css(".booster-canister__line--season")
    assert_select "#{ROOT} .booster-zoom__repost", 0
    assert_select ".booster__fallback form[action='/en/packs'] button", "Open the capsule"
    assert_select ".booster__fallback a", 0
  end

  test "an empty reserve: no form in the fallback, the screen told so, in French with its delimiter" do
    create_pack(@player, available_at: 1.day.from_now)
    sign_in(@player)

    get booster_path(locale: :fr)

    assert_response :success
    assert_equal 0, bank_value("available")
    assert_equal "\u00A0", value("delimiter")
    assert_select "#{ROOT} .booster__empty:not([hidden]) .booster__empty-title", "Réserve vide"
    assert_select "#{ROOT} button.booster__open", /Ouvrir la capsule.*Réserve vide/
    assert_select "#{ROOT} .booster__value--reserve", "0 capsule"
    celebration = strings["celebration"]
    assert_equal [ "PALIER %{tier}", "SET COMPLET", "Résultat suivant", " ; " ], celebration.values_at("tierTitle", "completeTitle", "next", "announceSeparator")
    assert_equal({ "zero" => "%{count} PALIER ATTEINT", "one" => "%{count} PALIER ATTEINT", "other" => "%{count} PALIERS ATTEINTS" }, celebration["folded"])
    assert_equal "argent", celebration.dig("spokenTiers", "silver")
    assert_equal "/fr/cards/SLUG", value("card-url")
    assert_select ".booster__fallback form", 0
    assert_select ".booster__fallback a", 0
    assert_select ".packs-chip--static .packs-chip__label", "en réserve"
  end

  test "a daily bonus pack first in line: the screen is told the next booster holds three cards" do
    create_pack(@player, kind: :bonus, available_at: 2.hours.ago)
    create_pack(@player, available_at: 1.hour.ago)
    sign_in(@player)

    get booster_path(locale: :en)

    assert_response :success
    assert_equal [ 3, "5" ], [ bank_value("nextPackSize"), value("pack-size") ]
    assert_select "#{ROOT} .booster__value", "3"
    assert_select "#{ROOT} .booster__canister-facts", "3 cards"
  end

  test "given one of the player's opened packs, the screen carries it: its cards in drawn order, their faces, the current bank" do
    pack = create_pack(@player, cards: fixture_tier_ids, opened_at: 1.minute.ago)
    reach_set_tiers(pack)
    create_pack(@player, available_at: 1.hour.ago)
    sign_in(@player)

    assert_no_difference -> { Game::Pack.where(player_id: @player.id, opened_at: nil).count } do
      get booster_path(locale: :fr, pack: pack.token)
    end

    assert_response :success
    assert_select "meta[name=turbo-cache-control][content=no-cache]"
    assert_select "[style]", 0
    shown = opened("pack").sole
    assert_equal [ pack.token, "regular", "standard", "/fr/packs/#{pack.token}" ], %w[data-token data-kind data-card-back data-url].map { shown[it] }
    cards = opened("card")
    assert_equal %w[tin-soldier green-hills blue-depths portal golden-crown], cards.map { it["data-slug"] }
    assert_equal %w[0 1 2 3 4], cards.map { it["data-index"] }
    assert_equal "Soldat de plomb", cards.first["data-title"]
    assert_equal [ "1" ] * 5, cards.map { it["data-season"] }
    faces = opened("face")
    assert_equal 15, faces.size
    assert_equal %w[s m xl], faces.first(3).map { it["data-size"] }
    assert_equal 1, Nokogiri::HTML5.fragment(faces.first.inner_html).css(".card.card--s").size
    rows = Game::PackSetTiers.call(pack)
    refute_empty rows
    assert_equal rows.size, opened("setTier").size
    opened("setTier").zip(rows).each do |shown_row, row|
      expected = [ row.kind, row.key, I18n.with_locale(:fr) { SetLabel.for(row) }, row.tier, row.required, row.held, row.total, library_set_path(locale: :fr, kind: row.kind, key: row.key) ]
      assert_equal expected.map(&:to_s), %w[kind key name tier required held total url].map { shown_row["data-#{it}"] }
      refute_empty row.thresholds
      assert_equal row.thresholds.map { |tier, required| "#{tier}:#{required}" }.join(" "), shown_row["data-thresholds"]
    end
    assert_equal 1, bank_value("available")
    assert_empty id_attributes
    assert_select ".booster__fallback form[action='/fr/packs']"
  end

  test "a pack shown again after a new season is published keeps each card's own season" do
    pack = create_pack(@player, cards: fixture_tier_ids, opened_at: 1.minute.ago)
    Catalog::Season.create!(status: :published, number: 2, published_at: Time.current)
    sign_in(@player)

    get booster_path(locale: :en, pack: pack.token)

    assert_response :success
    assert_equal "2", value("season")
    assert_equal [ "1" ] * 5, opened("card").map { it["data-season"] }
  end

  test "another player's pack, one not opened or an unknown token shows the canister as without one" do
    foreign = create_pack(accounts_players(:moderator), cards: fixture_tier_ids, opened_at: 1.minute.ago)
    sealed = create_pack(@player, available_at: 1.hour.ago)
    sign_in(@player)

    [ foreign.token, sealed.token, "nope", "" ].each do |token|
      get booster_path(locale: :en, pack: token)

      assert_response :success, token
      assert_empty opened("pack"), token
      assert_empty opened("card"), token
      assert_equal 1, bank_value("available"), token
    end
    get booster_path(locale: :en, pack: [ foreign.token ])
    assert_empty opened("pack")
  end

  test "with no standard pack the screen opens on the special reserve and names its origin" do
    create_pack(@player, kind: :bonus, available_at: 1.hour.ago)
    sign_in(@player)

    get booster_path(locale: :en)

    assert_equal "special", value("reserve")
    assert_equal "bonus", bank_value("nextSpecialKind")
    assert_select "#{ROOT} [role=tab][aria-selected=true]", text: /SPECIAL · 1/
    assert_select "#{ROOT} [role=tab][data-reserve=standard][disabled]", text: /No standard capsule yet/
    assert_select "#{ROOT} .booster__origin:not([hidden])", "DAILY CAPSULE"
  end

  test "with only special capsules the no-JS fallback opens the special reserve" do
    create_pack(@player, kind: :bonus, available_at: 1.hour.ago)
    sign_in(@player)

    get booster_path(locale: :en)

    assert_select ".booster__fallback form[action=?] button", "/en/packs?reserve=special", text: "Open the capsule"
  end

  test "with both kinds the screen opens on standard unless the special reserve is asked for" do
    create_pack(@player, available_at: 1.hour.ago)
    create_pack(@player, kind: :reward, available_at: 1.hour.ago)
    sign_in(@player)

    get booster_path(locale: :en)
    assert_equal "standard", value("reserve")
    assert_select "#{ROOT} [role=tab]:not([disabled])", 2

    get booster_path(locale: :en, reserve: "special")
    assert_equal "special", value("reserve")

    get booster_path(locale: :en, reserve: "nonsense")
    assert_equal "standard", value("reserve")
  end

  test "asking for the special reserve while it is empty falls back to standard" do
    create_pack(@player, available_at: 1.hour.ago)
    sign_in(@player)

    get booster_path(locale: :en, reserve: "special")

    assert_equal "standard", value("reserve")
    assert_select "#{ROOT} [role=tab][data-reserve=special][disabled]", text: /No special capsule yet/
  end

  test "each special origin is told to the screen so the canister wears its own look" do
    create_pack(@player, kind: :bonus, available_at: 1.hour.ago)
    sign_in(@player)

    get booster_path(locale: :en)
    assert_select "#{ROOT}[data-origin=bonus]"

    Game::Pack.where(player_id: @player.id).delete_all
    create_pack(@player, kind: :reward, available_at: 1.hour.ago)

    get booster_path(locale: :en)
    assert_select "#{ROOT}[data-origin=reward]"
  end

  test "the standard reserve carries no origin look, even with a special capsule waiting" do
    create_pack(@player, available_at: 1.hour.ago)
    create_pack(@player, kind: :bonus, available_at: 1.hour.ago)
    sign_in(@player)

    get booster_path(locale: :en)

    assert_equal "standard", value("reserve")
    assert_select "#{ROOT}[data-origin]", 0
  end
end

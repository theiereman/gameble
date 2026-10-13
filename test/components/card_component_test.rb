require "test_helper"

class CardComponentTest < ViewComponent::TestCase
  def card(**overrides)
    Catalog::CardView.new(id: "blue-depths", title: "Blue Depths", publisher: "Deepwater", year: 2014, season_number: 1,
      rarity: "rare", image_url: "/art.png", number: 4_215, genre: "puzzle", **overrides)
  end

  def render_card(view = card, locale: :en, **options)
    I18n.with_locale(locale) { render_inline(CardComponent.new(card: view, **options)) }
  end

  test "a medium rare face by default: frame, title band, art, genre and year, rarity line" do
    render_card

    assert_selector "span.card.card--m.card--rarity-rare[data-controller=tilt][data-tilt-max-value='10']"
    assert_no_selector ".card--booster"
    assert_selector ".card > .card__body > .card__band > .card__title", text: "Blue Depths"
    assert_selector ".card__band > .card__publisher", text: "Deepwater"
    assert_selector ".card__body > .card__art + .card__line + .card__line.card__line--rarity"
    assert_selector ".card__line:not(.card__line--rarity) > .card__genre", text: "Puzzle"
    assert_selector ".card__line:not(.card__line--rarity) > .card__year", text: "2014"
    assert_selector ".card__line--rarity > svg.pixel-icon.card__rarity-icon[aria-hidden=true] + .card__rarity", text: "Rare"
    assert_selector ".card__line--rarity > .card__number", text: "#4 215", exact_text: true
  end

  { s: [ 50, 51 ], m: [ 72, 74 ], l: [ 94, 97 ], xl: [ 109, 112 ] }.each do |size, (width, height)|
    test "the #{size} face draws its art at #{width} × #{height} art pixels with the xl palette" do
      render_card(size:)

      assert_selector "span.card.card--#{size}"
      assert_selector ".card__art[data-controller=card-art][data-card-art-url-value='/art.png']" \
        "[data-card-art-width-value='#{width}'][data-card-art-height-value='#{height}']" \
        "[data-card-art-palette-width-value='109'][data-card-art-palette-height-value='112']"
      assert_selector ".card__art > canvas.card__canvas[width='#{width}'][height='#{height}'][aria-hidden=true][data-card-art-target=canvas]"
      assert_selector ".card__art > .card__missing > svg.pixel-icon.card__missing-icon + .card__missing-text", text: "Image unavailable", visible: :all
      assert_selector ".card__title", text: "Blue Depths"
      assert_selector ".card__genre", text: "Puzzle"
      assert_selector ".card__year", text: "2014"
      assert_selector ".card__rarity", text: "Rare"
    end
  end

  test "the publisher shows from m up, never on s" do
    render_card(size: :s)
    assert_no_selector ".card__publisher"

    %i[m l xl].each do |size|
      render_card(size:)
      assert_selector ".card__publisher", text: "Deepwater"
    end
  end

  test "the number: alone on s and m, with its season on l and xl" do
    view = card(season_number: 12, number: 1_000_000)
    { s: "#1 000 000", m: "#1 000 000", l: "S12 · #1 000 000", xl: "S12 · #1 000 000" }.each do |size, label|
      render_card(view, size:)
      assert_selector ".card__number", exact_text: label
    end
  end

  test "the compact rarity icon on s and m, the large one on l and xl" do
    %i[s m].each do |size|
      render_card(size:)
      assert_selector ".card__rarity-icon[width='10'][height='10']"
    end
    %i[l xl].each do |size|
      render_card(size:)
      assert_selector ".card__rarity-icon[width='14'][height='14']"
    end
  end

  test "no genre, no number, no publisher: each element is left out" do
    render_card(card(genre: nil, number: nil, publisher: nil), size: :xl)

    assert_no_selector ".card__genre"
    assert_no_selector ".card__number"
    assert_no_selector ".card__publisher"
    assert_selector ".card__year", text: "2014"
    assert_selector ".card__rarity", text: "Rare"
  end

  test "a genre outside the curated list is its key humanised" do
    render_card(card(genre: "space_trucking"))

    assert_selector ".card__genre", text: "Space trucking"
  end

  test "a long title stays whole in the DOM" do
    title = "The Long Chronicles of the Amethyst Archive and the Keys Its Keepers Lost at Sea"
    render_card(card(title:))

    assert_equal title, page.find(".card__title").text
  end

  def assert_reflection(rarity)
    shining = rarity.to_s == "legendary"
    assert_selector ".card > .card__effects[aria-hidden=true] > .card__reflection--ceiling:first-child"
    assert_selector ".card__effects > .card__reflection--strips"
    assert_equal shining, page.has_selector?(".card__reflection--ceiling + .card__reflection--iridescence + .card__reflection--strips"), "#{rarity} iridescence"
    assert_equal shining, page.has_selector?(".card__reflection--strips + .card__glitter[data-tilt-target=glitter][data-glitter-seed]:last-child"), "#{rarity} glitter"
    assert_no_selector ".card__holo, .card__foil, .card__glare"
  end

  test "every tier reflects the studio on its varnish; only the legendary one adds iridescence and glitter" do
    Catalog::Rarity::TIERS.each_value do |rarity|
      render_card(card(rarity: rarity.to_s))

      assert_reflection(rarity)
    end
  end

  test "in the booster: the same reflection, iridescence and glitter, and a stronger tilt" do
    Catalog::Rarity::TIERS.each_value do |rarity|
      render_card(card(rarity: rarity.to_s), booster: true)

      assert_selector ".card.card--booster.card--rarity-#{rarity}[data-tilt-max-value='16']"
      assert_reflection(rarity)
    end
  end

  test "a legendary card's glitter is seeded from its season and number, the same on every render" do
    render_card(card(rarity: "legendary", season_number: 2, number: 42))
    assert_selector ".card__glitter[data-glitter-seed='2000042']"

    render_card(card(rarity: "legendary", season_number: 2, number: 42), size: :xl, booster: true)
    assert_selector ".card__glitter[data-glitter-seed='2000042']"

    render_card(card(rarity: "legendary", season_number: 1, number: nil))
    assert_selector ".card__glitter[data-glitter-seed='1000000']"
  end

  test "each tier's icon and name" do
    Catalog::Rarity::TIERS.each do |tier, rarity|
      render_card(card(rarity: rarity.to_s), size: :s)
      assert_selector ".card--rarity-#{rarity} .card__rarity", text: I18n.t("catalog.rarity.#{rarity}", locale: :en)
      paths = ShellHelper.pixel_source("rarity-compact-#{tier}").scan(/ d="([^"]+)"/).flatten
      assert_equal paths, page.all(".card__rarity-icon path", visible: :all).map { it["d"] }
    end
  end

  test "French words" do
    render_card(card(rarity: "uncommon"), locale: :fr)

    assert_selector ".card__rarity", text: "Peu commune"
    assert_selector ".card__genre", text: "Réflexion"
    assert_selector ".card__missing-text", text: "Image indisponible", visible: :all
  end

  test "no style attribute, nothing focusable, no id" do
    %i[s m l xl].each do |size|
      render_card(card(rarity: "legendary"), size:, booster: true)

      assert_no_selector "[style]", visible: :all
      assert_no_selector "[tabindex], a, button, input", visible: :all
      assert_no_selector "[id]", visible: :all
    end
  end

  test "an unknown size is refused" do
    assert_raises(ArgumentError) { CardComponent.new(card:, size: :huge) }
    assert_raises(ArgumentError) { CardComponent.new(card:, size: :small) }
  end

  test "the rarity names of a card's labels" do
    strings = I18n.with_locale(:en) { CardStrings.new }

    assert_equal "Uncommon", strings.rarity_name("uncommon")
    assert_equal "Legendary", strings.rarity_name(:legendary)
  end
end

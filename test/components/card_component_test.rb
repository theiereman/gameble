require "test_helper"

class CardComponentTest < ViewComponent::TestCase
  def card(**overrides)
    Catalog::CardView.new(id: "blue-depths", title: "Blue Depths", publisher: "Deepwater", year: 2014, season_number: 1,
      rarity: "sapphire", dust: 0, image_url: "/art.png", **overrides)
  end

  def render_card(view = card, **options)
    I18n.with_locale(:en) { render_inline(CardComponent.new(card: view, strings: CardStrings.for([ view ]), **options)) }
  end

  test "a small sapphire face: title, year tag, season seal, piping, hidden rarity, no publisher" do
    render_card

    assert_selector "span.card.card--small.card--face.card--rarity-sapphire.card--dust-0"
    assert_selector ".card__title", text: "Blue Depths"
    assert_selector ".card__year .visually-hidden", text: "2014"
    assert_selector ".card__year .card__glyph use", count: 4
    assert_selector ".card__year use[href$='#glyph-2']", count: 1
    assert_selector ".card__season:not(.card__season--wide) .card__season-seal use[href$='#season-seal']"
    assert_selector ".card__season .visually-hidden", text: "Season 1"
    assert_selector ".card__season use[href$='#glyph-S']"
    assert_selector ".card__piping[aria-hidden=true]"
    assert_selector ".card__plate .visually-hidden", text: "Sapphire"
    assert_no_selector ".card__publisher"
    assert_no_selector ".card__shine"
    assert_selector ".card__art[data-controller=card-art][data-card-art-url-value='/art.png'][data-card-art-width-value='68'][data-card-art-height-value='108'] canvas.card__canvas[data-card-art-target=canvas]"
  end

  test "nothing in a card is focusable or interactive" do
    render_card(size: :large)

    assert_no_selector "[tabindex], a, button, input"
    assert_no_selector "[id]"
  end

  test "a large face credits the publisher when there is one" do
    render_card(size: :large)
    assert_selector ".card--large .card__publisher", text: "© Deepwater"
    assert_selector ".card__art[data-card-art-width-value='104'][data-card-art-height-value='164']"
    assert_selector ".card__season-seal use[href$='#season-seal']"

    render_card(card(publisher: nil), size: :large)
    assert_no_selector ".card__publisher"
  end

  test "a long title stays whole in the DOM" do
    title = "The Long Chronicles of the Amethyst Archive and the Keys Its Keepers Lost at Sea"
    render_card(card(title:))

    assert_equal 80, title.length
    assert_equal title, page.find(".card__title").text
  end

  test "a two-digit season widens the seal and writes both digits" do
    render_card(card(season_number: 12))

    assert_selector ".card__season.card__season--wide .card__season-seal use[href$='#season-seal-wide']"
    assert_equal %w[S 1 2], page.all(".card__season .card__glyph use", visible: :all).map { it[:href].split("#").last.delete_prefix("glyph-") }
    assert_selector ".card__season .visually-hidden", text: "Season 12"
  end

  test "a legendary face has a gold frame, the sweep and the sparkles" do
    render_card(card(rarity: "gold"))

    assert_selector ".card.card--rarity-gold .card__shine[aria-hidden=true] .card__sweep"
    assert_selector ".card__shine .card__sparkle", count: CardComponent::SPARKLES
  end

  Catalog::Rarity::TIERS.each_value do |rarity|
    test "a #{rarity} back: its seal and a label with the rarity" do
      render_card(card(rarity: rarity.to_s), side: :back)

      name = I18n.t("catalog.rarity.#{rarity}", locale: :en)
      assert_selector "span.card.card--back.card--rarity-#{rarity}[role=img][aria-label='Face-down card, #{name}']"
      assert_selector ".card__seal[aria-hidden=true] use[href$='#seal-#{rarity}']"
      assert_no_selector ".card__title"
    end
  end

  test "dust: no element at level 0, the level's overlay last at 1 to 4" do
    render_card(side: :back)
    assert_selector ".card.card--dust-0"
    assert_no_selector ".card__dust"

    (1..4).each do |level|
      render_card(card(dust: level), side: :back)
      assert_selector ".card.card--dust-#{level} > .card__dust[aria-hidden=true]:last-child"
    end
  end

  test "French strings" do
    view = card(season_number: 3)
    I18n.with_locale(:fr) { render_inline(CardComponent.new(card: view, strings: CardStrings.for([ view ]), side: :back)) }
    assert_selector ".card[aria-label='Carte face cachée, Saphir']"

    I18n.with_locale(:fr) { render_inline(CardComponent.new(card: view, strings: CardStrings.for([ view ]))) }
    assert_selector ".card__season .visually-hidden", text: "Saison 3"
  end

  test "a season without its string fails loudly" do
    assert_raises(KeyError) do
      render_inline(CardComponent.new(card: card(season_number: 4), strings: CardStrings.new(season_numbers: [ 1 ])))
    end
  end

  test "an unknown size or side is refused" do
    assert_raises(ArgumentError) { CardComponent.new(card:, strings: CardStrings.new, size: :huge) }
    assert_raises(ArgumentError) { CardComponent.new(card:, strings: CardStrings.new, side: :edge) }
  end

  test "the strings for the React card, resolved on the server" do
    props = I18n.with_locale(:en) { CardStrings.new(season_numbers: [ 12, 1, 12 ]).to_props }

    assert_equal "Face-down card", props[:faceDown]
    assert_equal "Face-down card, Gold", props[:faceDownByRarity]["gold"]
    assert_equal "Emerald", props[:rarityNames]["emerald"]
    assert_equal({ "1" => "Season 1", "12" => "Season 12" }, props[:seasons])
  end
end

require "test_helper"

class MarketRowComponentTest < ViewComponent::TestCase
  Card = Struct.new(:title, :rarity, :image_url)

  def card(rarity: :rare) = Card.new("Blue Depths", rarity, "https://example.test/blue.jpg")

  def row(tone: :accent, **options)
    render_inline MarketRowComponent.new(card: card, href: "/en/market/listings/TOKEN", token: "TOKEN", status: "IN PROGRESS", tone:,
      facts: [ [ "Price", "1,300" ] ], **options) do |component|
      component.with_action { "ACTION" }
    end
  end

  test "the title is a link carrying the row's token, and comes before the action" do
    row

    assert_selector "li.market-row a.market-row__title[href='/en/market/listings/TOKEN'][data-row-token=TOKEN]", text: "Blue Depths"
    html = page.native.to_html
    assert_operator html.index("market-row__title"), :<, html.index("market-row__action")
    assert_no_selector "a .market-row__action"
    assert_selector ".market-row__action", text: "ACTION"
  end

  test "the chip is a word with its tone class, and the facts are labelled" do
    %i[accent lime orange gold muted].each do |tone|
      row(tone:)

      assert_selector ".market-row__chip.market-row__chip--#{tone}", text: "IN PROGRESS"
    end
    assert_selector ".market-row__fact dt", text: "Price"
    assert_selector ".market-row__fact dd", text: "1,300"
  end

  test "the thumbnail is decorative and no element carries a style attribute" do
    row

    assert_selector "img.market-row__thumb[alt=''][width='40'][height='40']"
    assert_no_selector "[style]"
  end

  test "the rarity reads in words with its class" do
    row

    assert_selector ".market-row__rarity.market-row__rarity--rare", text: "Rare"
  end

  test "an unknown tone is refused" do
    assert_raises(ArgumentError) { row(tone: :pink) }
  end
end

require "test_helper"

class BrotherhoodCardComponentTest < ViewComponent::TestCase
  Pioneer = Data.define(:player)

  def card
    Catalog::CardView.new(id: "outer-wilds", title: "Outer Wilds", publisher: "Mobius Digital", year: 2019, season_number: 1,
      rarity: "epic", image_url: "/art.png", number: 12, genre: "adventure", card_id: 7)
  end

  def player(fixture, **attributes)
    accounts_players(fixture).tap { it.assign_attributes(attributes) }
  end

  def render_card(found:, pioneer: nil, viewer: nil, locale: :en)
    I18n.with_locale(locale) do
      render_inline(BrotherhoodCardComponent.new(card:, found:, pioneer: pioneer && Pioneer.new(player: pioneer), viewer:,
        context: { set_kind: "theme", set_key: "space", from: "inventory" }))
    end
  end

  test "a found card shows its face, its game and its pioneer's name, and is named after them" do
    lea = player(:player, persona_name: "Léa", visibility: "public")
    render_card(found: true, pioneer: lea)

    assert_selector "li.collection-slot.brotherhood-card > a.card-link[aria-label='Outer Wilds, Mobius Digital, 2019, Epic, discovered by Léa']" \
      "[href='/en/cards/outer-wilds/seasons/1?from=inventory&set_key=space&set_kind=theme'] > .card.card--grid:not(.card--not-owned)"
    assert_selector ".brotherhood-card__game[aria-hidden=true]", text: "Outer Wilds"
    assert_selector ".brotherhood-card__pioneer[aria-hidden=true]", text: "Léa"
    assert_no_selector ".brotherhood-card__badge"
  end

  test "a private pioneer is named without a link, a banned one reads anonymous" do
    render_card(found: true, pioneer: player(:player, persona_name: "Léa", visibility: "private"))
    assert_selector ".brotherhood-card__pioneer[aria-hidden=true]", text: "Léa"
    assert_no_selector ".brotherhood-card__pioneer a"

    render_card(found: true, pioneer: accounts_players(:banned))
    assert_selector ".brotherhood-card__pioneer[aria-hidden=true]", text: "anonymous"
    assert_selector "a.card-link[aria-label$='discovered by anonymous']"
  end

  test "the viewer's own discovery reads You with the YOU badge, in French too" do
    lea = player(:player, persona_name: "Léa")
    render_card(found: true, pioneer: lea, viewer: lea, locale: :fr)

    assert_selector "li.brotherhood-card--mine .brotherhood-card__badge[aria-hidden=true]", text: "VOUS"
    assert_selector ".brotherhood-card__pioneer", text: "Vous"
    assert_selector "a.card-link[aria-label='Outer Wilds, Mobius Digital, 2019, Épique, découverte par vous']"
  end

  test "a card to discover shows the not-owned face and To discover, for a visitor too" do
    render_card(found: false)

    assert_selector "a.card-link[aria-label='Outer Wilds, Mobius Digital, 2019, Epic, to discover'] > .card.card--not-owned"
    assert_selector ".brotherhood-card__pioneer.brotherhood-card__pioneer--none[aria-hidden=true]", text: "To discover"
    assert_no_selector ".brotherhood-card__badge"
  end
end

# The words a card's back speaks, resolved on the server in the current
# locale and passed once per island (AD-16, AD-18): the rarity names and the
# face-down labels (by rarity, and the plain one for a hidden seal). The
# client interpolates nothing. Card faces read their words themselves
# (CardComponent).
#
#   strings = CardStrings.new
#   turbo_mount("…", props: { cardStrings: strings.to_props, … })
class CardStrings
  def initialize
    @rarity_names = Catalog::Rarity::TIERS.values.to_h { |name| [ name.to_s, I18n.t("catalog.rarity.#{name}") ] }
    @face_down = I18n.t("cards.face_down")
    @face_down_by_rarity = @rarity_names.transform_values { |rarity| I18n.t("cards.face_down_with_rarity", rarity:) }
  end

  def rarity_name(rarity) = @rarity_names.fetch(rarity.to_s)

  # "Face-down card, Rare", or "Face-down card" without a rarity.
  def face_down(rarity = nil) = rarity ? @face_down_by_rarity.fetch(rarity.to_s) : @face_down

  # The TypeScript CardStrings (app/frontend/lib/card_types.ts).
  def to_props
    { rarityNames: @rarity_names, faceDown: @face_down, faceDownByRarity: @face_down_by_rarity }
  end
end

# The words a card shows or speaks, resolved on the server in the current
# locale and passed once per island (AD-16, AD-18): the rarity names, the
# face-down labels (by rarity, and the plain one for a hidden seal) and the
# "Season n" of each season shown. The client interpolates nothing.
#
#   strings = CardStrings.for(cards)
#   render CardComponent.new(card:, strings:)
#   turbo_mount("…", props: { strings: strings.to_props, … })
class CardStrings
  # For a list of Catalog::CardViews: their seasons are resolved.
  def self.for(cards)
    new(season_numbers: cards.map(&:season_number))
  end

  def initialize(season_numbers: [])
    @rarity_names = Catalog::Rarity::TIERS.values.to_h { |name| [ name.to_s, I18n.t("catalog.rarity.#{name}") ] }
    @face_down = I18n.t("cards.face_down")
    @face_down_by_rarity = @rarity_names.transform_values { |rarity| I18n.t("cards.face_down_with_rarity", rarity:) }
    @seasons = season_numbers.uniq.sort.to_h { |number| [ number, I18n.t("cards.season", number:) ] }
  end

  def rarity_name(rarity) = @rarity_names.fetch(rarity.to_s)

  # "Face-down card, Sapphire", or "Face-down card" without a rarity.
  def face_down(rarity = nil) = rarity ? @face_down_by_rarity.fetch(rarity.to_s) : @face_down

  def season(number) = @seasons.fetch(number)

  # The TypeScript CardStrings (app/frontend/components/Card.tsx).
  def to_props
    { rarityNames: @rarity_names, faceDown: @face_down, faceDownByRarity: @face_down_by_rarity,
      seasons: @seasons.transform_keys(&:to_s) }
  end
end

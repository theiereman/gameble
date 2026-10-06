# The rarity names a card's labels speak, resolved once in the current
# locale (AD-18): the card detail and the links that open it name a card's
# rarity in words. Card faces read their words themselves (CardComponent).
#
#   strings = CardStrings.new
#   strings.rarity_name("legendary") # => "Légendaire"
class CardStrings
  def initialize
    @rarity_names = Catalog::Rarity::TIERS.values.to_h { |name| [ name.to_s, I18n.t("catalog.rarity.#{name}") ] }
  end

  def rarity_name(rarity) = @rarity_names.fetch(rarity.to_s)
end

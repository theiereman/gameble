class CardStrings
  def initialize
    @rarity_names = Catalog::Rarity::TIERS.values.to_h { |name| [ name.to_s, I18n.t("catalog.rarity.#{name}") ] }
  end

  def rarity_name(rarity) = @rarity_names.fetch(rarity.to_s)
end

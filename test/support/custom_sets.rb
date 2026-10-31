# Custom sets made through the operation, over the fixture season's five
# published cards unless other card ids are given.
module CustomSets
  def fixture_card_ids
    %i[common_card uncommon_card rare_card portal legendary_card].map { catalog_cards(it).id }
  end

  def create_custom_set(player, name: "Mes favoris", card_ids: fixture_card_ids.first(3))
    Game::CreateCustomSet.new.call(player:, name:, card_ids:).value!
  end
end

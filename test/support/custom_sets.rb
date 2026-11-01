# Custom sets made through the operation, over the fixture season's five
# published cards unless other card ids are given; a Steam library set
# written straight, as a sync leaves it.
module CustomSets
  def fixture_card_ids
    %i[common_card uncommon_card rare_card portal legendary_card].map { catalog_cards(it).id }
  end

  def create_custom_set(player, name: "Mes favoris", card_ids: fixture_card_ids.first(3))
    Game::CreateCustomSet.new.call(player:, name:, card_ids:).value!
  end

  def create_library_set(player, card_ids: fixture_card_ids.first(3), synced_at: 1.day.ago, library_private_since: nil)
    library_set = Game::CustomSet.create!(player_id: player.id, kind: Game::CustomSet::STEAM_LIBRARY, synced_at:, library_private_since:)
    Game::CustomSetGame.insert_all!(card_ids.map { { custom_set_id: library_set.id, card_id: it } }) if card_ids.any?
    library_set
  end
end

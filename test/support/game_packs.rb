# Builds packs straight into a player's bank, for tests of opening and of the
# bank. Cards default to the fixture season's portal_one, as many times as
# the database allows the kind: five, three for a daily bonus pack.
module GamePacks
  def create_pack(player, cards: nil, available_at: 1.minute.ago, kind: :regular, opened_at: nil)
    cards ||= Array.new(kind.to_s == "bonus" ? Game::Pack::BONUS_SIZE : Game::Pack::SIZE, catalog_card_seasons(:portal_one).id)
    Game::Pack.create!(player_id: player.id, kind:, season_id: catalog_seasons(:one).id, card_season_ids: cards,
      available_at:, opened_at:)
  end

  # The fixture season's card-season ids, common to legendary.
  def fixture_tier_ids
    %i[common_card_one uncommon_card_one rare_card_one portal_one legendary_card_one].map { |name| catalog_card_seasons(name).id }
  end

  def game_events(player, type = nil)
    events = Rails.configuration.event_store.read.stream(Game::Operation.stream_name(player.id)).to_a
    type ? events.select { |event| event.is_a?(type) } : events
  end
end

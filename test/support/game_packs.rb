# Builds packs straight into a player's bank, for tests of opening and of the
# bank, in the fixture season unless another is given (a pack of an older
# season is re-drawn when it opens). Cards default to the fixture season's
# portal_one, as many times as the database allows the kind: five, three
# for a daily bonus pack. Also
# leaves a bank short and checks that no pack was spent twice, for the races
# between bank operations.
module GamePacks
  def create_pack(player, cards: nil, available_at: 1.minute.ago, kind: :regular, opened_at: nil, season: catalog_seasons(:one))
    cards ||= Array.new(kind.to_s == "bonus" ? Game::Pack::BONUS_SIZE : Game::Pack::SIZE, catalog_card_seasons(:portal_one).id)
    Game::Pack.create!(player_id: player.id, kind:, season_id: season.id, card_season_ids: cards,
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

  # Opens packs while no season is published, so nothing replaces them: the
  # bank is left short, as the publication's healing finds it.
  def open_unpublished(player, count)
    current = Game::DrawPool.method(:current)
    Game::DrawPool.define_singleton_method(:current) { nil }
    count.times { Game::OpenPack.new.call(player:).value! }
  ensure
    Game::DrawPool.define_singleton_method(:current, current)
  end

  # Every opened pack of the player was announced by one Game::PackOpened.
  def assert_opened_once(player)
    announced = game_events(player, Game::PackOpened).map { |event| event.data[:pack_id] }
    assert_equal announced.uniq, announced, "a pack was opened twice"
    assert_equal Game::Pack.where(player_id: player.id).where.not(opened_at: nil).ids.sort, announced.sort
  end

  # Every opened pack of a player who holds no other card was spent once:
  # opened once, and its cards credited once, Game::Pack::SIZE per regular
  # pack and Game::Pack::BONUS_SIZE per bonus pack.
  def assert_spent_once(player)
    assert_opened_once(player)
    opened = Game::Pack.where(player_id: player.id).where.not(opened_at: nil)
    cards = (opened.regular.count * Game::Pack::SIZE) + (opened.bonus.count * Game::Pack::BONUS_SIZE)
    assert_equal cards, Game::Holding.where(player_id: player.id).sum(:quantity), "the opened packs' cards should be credited once"
  end
end

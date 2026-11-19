require "test_helper"

# Game::GrandInventory: the published season's cards judged by every
# player's first discoveries, over all seasons or the current one.
class Game::GrandInventoryTest < ActiveSupport::TestCase
  setup do
    @player = accounts_players(:player)
    @banned = accounts_players(:banned)
  end

  def discovery(name) = game_first_discoveries(name)

  def card_id(name) = catalog_card_seasons(name).card_id

  # A second published season holding a new edition of Portal, found by the
  # player now, and of Tin Soldier, found by nobody yet.
  def publish_second_season
    season = Catalog::Season.create!(status: :published, number: 2, published_at: Time.current)
    rows = [ [ :portal_one, 5, 1 ], [ :common_card_one, 1, 2 ] ].map do |name, rarity, number|
      { card_id: card_id(name), season_id: season.id, prestige_score: 0.5, rating: 90, rarity:, number: }
    end
    portal_two, = Catalog::CardSeason.insert_all!(rows, returning: :id).rows.flatten
    Game::FirstDiscovery.create!(card_season_id: portal_two, player_id: @player.id, discovered_at: Time.current)
    season
  end

  test "all seasons: a card is found once any edition is, by its earliest discovered edition's pioneer" do
    publish_second_season
    inventory = Game::GrandInventory.new(seasons: :all)

    assert_equal 2, inventory.total
    assert_equal 2, inventory.found_count
    assert inventory.found?(catalog_cards(:common_card))
    pioneer = inventory.pioneer_of(catalog_cards(:portal))
    assert_equal @banned, pioneer.player
    assert_equal discovery(:portal_one).discovered_at, pioneer.discovered_at
    assert_equal "portal", pioneer.card.id
    assert_equal 2, pioneer.card.season_number
  end

  test "current season: a card is found once the published edition is, by that edition's pioneer" do
    publish_second_season
    inventory = Game::GrandInventory.new(seasons: :current)

    assert_equal 2, inventory.total
    assert_equal 1, inventory.found_count
    assert_not inventory.found?(catalog_cards(:common_card))
    assert_nil inventory.pioneer_of(catalog_cards(:common_card))
    assert_equal @player, inventory.pioneer_of(catalog_cards(:portal)).player
    assert_equal({ common: [ 0, 1 ], uncommon: [ 0, 0 ], rare: [ 0, 0 ], epic: [ 0, 0 ], legendary: [ 1, 1 ] }, inventory.per_rarity)
    assert_equal [ 1, 1 ], Game::GrandInventory.new(seasons: :all).per_rarity[:common]
  end

  test "a banned pioneer keeps their cards found" do
    inventory = Game::GrandInventory.new(seasons: :all)

    assert_equal 5, inventory.found_count
    assert inventory.pioneer_of(catalog_cards(:portal)).player.removed?
  end

  test "the latest discovery and the pace follow the scope's pioneers: a new edition of a found card counts only in the current season" do
    publish_second_season

    current = Game::GrandInventory.new(seasons: :current)
    assert_equal @player, current.latest_discovery.player
    assert_equal "portal", current.latest_discovery.card.id
    assert_equal 1, current.found_since(1.day.ago)

    all = Game::GrandInventory.new(seasons: :all)
    assert_equal @banned, all.latest_discovery.player
    assert_equal 0, all.found_since(1.day.ago)
    assert_equal 2, all.found_since(3.weeks.ago)
  end

  test "with nothing discovered: nothing found, no latest discovery" do
    Game::FirstDiscovery.delete_all
    inventory = Game::GrandInventory.new(seasons: :all)

    assert_equal 5, inventory.total
    assert_equal 0, inventory.found_count
    assert_nil inventory.latest_discovery
    assert_equal 0, inventory.found_since(1.year.ago)
    assert_equal [ 0, 1 ], inventory.set_progress(catalog_sets(:valve_one))
  end

  test "a set's progress counts its cards found in the scope; a complete set carries when it was completed" do
    inventory = Game::GrandInventory.new(seasons: :current)

    assert_equal [ 1, 1 ], inventory.set_progress(catalog_sets(:valve_one))
    progress = inventory.set_progresses.sole
    assert progress.complete?
    assert_equal discovery(:portal_one).discovered_at, progress.completed_at
  end

  test "the grid lists the latest discoveries first, then older ones, then the cards to discover in catalog order" do
    discovery(:legendary_card_one).destroy!
    discovery(:portal_one).update!(discovered_at: 1.hour.ago)
    discovery(:common_card_one).update!(player_id: @player.id)
    inventory = Game::GrandInventory.new(seasons: :all)
    cards = Catalog::CardSeason.where(season_id: catalog_seasons(:one).id)
    order = ->(states, viewer = nil) { inventory.cards_in_order(cards, states:, viewer:).map(&:id) }

    assert_equal %i[portal_one common_card_one uncommon_card_one rare_card_one legendary_card_one].map { catalog_card_seasons(it).id }, order.([])
    assert_equal [ catalog_card_seasons(:legendary_card_one).id ], order.([ "missing" ])
    assert_equal 4, order.([ "found" ]).size
    assert_equal [ catalog_card_seasons(:common_card_one).id ], order.([ "mine" ], @player)
    assert_equal 5, order.([ "mine" ]).size, "a visitor has no discoveries of their own to keep"
  end

  test "the state choice keeps the known states, drops TOUT beside another, and MES DÉCOUVERTES for a visitor" do
    assert_equal [ "all" ], Game::GrandInventory.states([])
    assert_equal [ "found" ], Game::GrandInventory.states(%w[all found bogus])
    assert_equal [ "all" ], Game::GrandInventory.states(%w[mine])
    assert_equal [ "mine" ], Game::GrandInventory.states(%w[mine], viewer: @player)
  end

  test "an unknown scope is refused" do
    assert_raises(ArgumentError) { Game::GrandInventory.new(seasons: :last) }
  end
end

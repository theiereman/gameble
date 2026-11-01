require "test_helper"
require_relative "../../support/game_packs"
require_relative "../../support/custom_sets"

# A player's Steam library set: created once for a player with a Steam
# identity, its games replaced by each sync with the published ones Steam
# lists, kept when Steam stops sharing the library; an event only when
# something changed, nothing written on a refusal.
class Game::LibrarySetOperationsTest < ActiveSupport::TestCase
  include GamePacks
  include CustomSets

  setup do
    @player = accounts_players(:player)
  end

  def create(player: @player) = Game::CreateLibrarySet.new.call(player:)

  def sync(token, card_ids, player: @player) = Game::SyncLibrarySet.new.call(player:, token:, card_ids:)

  def mark_private(token, player: @player) = Game::MarkLibraryPrivate.new.call(player:, token:)

  def writes = Game::CustomSet.count + Game::CustomSetGame.count + Game::CustomSet.maximum(:updated_at).to_f + Rails.configuration.event_store.read.count

  def games(library_set) = Game::CustomSetGame.where(custom_set_id: library_set.id).order(:card_id).pluck(:card_id)

  def assert_nothing_written(&operation)
    result = nil
    assert_no_difference(-> { writes }) { result = operation.call }
    result
  end

  def deleted_player
    accounts_players(:moderator).tap { it.update_columns(deleted_at: Time.current, steam_id: nil) }
  end

  test "a player with a Steam identity gets one library set, unnamed and never synced, with one event" do
    library_set = create.value!

    assert_equal [ "steam_library", nil, @player.id, nil, nil ],
      [ library_set.kind, library_set.name, library_set.player_id, library_set.synced_at, library_set.library_private_since ]
    assert_empty games(library_set)
    assert_equal [ { player_id: @player.id, custom_set_id: library_set.id } ], game_events(@player, Game::LibrarySetCreated).map(&:data)
  end

  test "a player who has a library set gets no second one and no event" do
    library_set = create.value!

    assert_equal library_set, assert_nothing_written { create }.value!
    assert_equal 1, game_events(@player, Game::LibrarySetCreated).size
  end

  test "a player who turned the sync off gets no set and no event" do
    @player.update_column(:steam_library_sync, false)

    assert_equal :library_sync_off, assert_nothing_written { create }.failure
  end

  test "a player who turned the sync off since they were loaded gets no set: the setting is read fresh" do
    stale = Accounts::Player.find(@player.id)
    @player.update_column(:steam_library_sync, false)

    assert_equal :library_sync_off, assert_nothing_written { create(player: stale) }.failure
  end

  test "a player without a Steam identity is refused" do
    @player.identities.where(provider: "steam").delete_all

    assert_equal :steam_identity_required, assert_nothing_written { create }.failure
  end

  test "no player, an unsaved, a banned or a deleted one is refused by every operation" do
    token = create.value!.token

    [ nil, Accounts::Player.new, accounts_players(:banned), deleted_player ].each do |player|
      assert_equal :player_required, assert_nothing_written { create(player:) }.failure
      assert_equal :player_required, assert_nothing_written { sync(token, fixture_card_ids, player:) }.failure
      assert_equal :player_required, assert_nothing_written { mark_private(token, player:) }.failure
    end
  end

  test "a sync replaces the games no longer listed by the new ones, dates the sync and writes one event" do
    library_set = create.value!
    a, b, c = fixture_card_ids.first(3)
    sync(library_set.token, [ b, c ]).value!

    travel 1.day do
      assert_equal library_set, sync(library_set.token, [ a, b ]).value!

      library_set.reload
      assert_equal [ a, b ].sort, games(library_set)
      assert_equal Time.current.to_i, library_set.synced_at.to_i
      assert_nil library_set.library_private_since
    end
    assert_equal [ { player_id: @player.id, custom_set_id: library_set.id } ] * 2, game_events(@player, Game::LibrarySetSynced).map(&:data)
  end

  test "a sync keeps only the published games listed, each once" do
    library_set = create.value!
    draft = Catalog::Season.create!(number: Catalog::Season.next_number)
    unpublished = Catalog::Card.create!(source_key: "src:901", release_date: Date.new(2000, 1, 1),
      image_url: "https://images.example.test/901.jpg", store_url: "https://store.example.test/901")
    Catalog::CardSeason.create!(card: unpublished, season: draft, prestige_score: 0.5, rating: 80, rarity: :rare, number: 1)
    portal = catalog_cards(:portal).id

    sync(library_set.token, [ portal, portal, unpublished.id, -1, nil, "1" ]).value!

    assert_equal [ portal ], games(library_set)
  end

  test "a sync that changes nothing dates the sync and writes no event" do
    library_set = create.value!
    sync(library_set.token, fixture_card_ids.first(2)).value!

    travel 1.day do
      sync(library_set.token, fixture_card_ids.first(2).reverse).value!

      assert_equal Time.current.to_i, library_set.reload.synced_at.to_i
    end
    assert_equal 1, game_events(@player, Game::LibrarySetSynced).size
  end

  test "an empty list from a public library empties the set" do
    library_set = create.value!
    sync(library_set.token, fixture_card_ids.first(2)).value!

    sync(library_set.token, []).value!

    assert_empty games(library_set)
    assert_equal 2, game_events(@player, Game::LibrarySetSynced).size
  end

  test "a library found private keeps its games and last sync, is marked once with one event, and a public sync clears the mark" do
    library_set = create.value!
    sync(library_set.token, fixture_card_ids.first(2)).value!
    synced_at = library_set.reload.synced_at

    travel 1.day do
      mark_private(library_set.token).value!

      library_set.reload
      assert_equal [ fixture_card_ids.first(2).sort, synced_at ], [ games(library_set), library_set.synced_at ]
      assert_equal Time.current.to_i, library_set.library_private_since.to_i
    end
    travel 2.days do
      assert_equal library_set, assert_nothing_written { mark_private(library_set.token) }.value!
    end
    assert_equal [ { player_id: @player.id, custom_set_id: library_set.id } ], game_events(@player, Game::LibrarySetMarkedPrivate).map(&:data)

    sync(library_set.token, fixture_card_ids.first(2)).value!
    assert_nil library_set.reload.library_private_since
  end

  test "a library private at its first sync is marked with no sync date" do
    library_set = create.value!

    mark_private(library_set.token).value!

    assert_nil library_set.reload.synced_at
    assert library_set.library_private_since
  end

  test "an unknown token, another player's library set or a custom set: nothing written, never a set created" do
    theirs = Game::CreateLibrarySet.new.call(player: accounts_players(:moderator)).value!.token
    custom = create_custom_set(@player).token

    [ theirs, custom, "1" * 24, nil, 42 ].each do |token|
      assert_nil assert_nothing_written { sync(token, fixture_card_ids) }.value!
      assert_nil assert_nothing_written { mark_private(token) }.value!
    end
    assert_not Game::CustomSet.steam_library.exists?(player_id: @player.id)
  end

  test "a player deleted after they were read is refused under the bank lock" do
    token = create.value!.token
    Accounts::Player.where(id: @player.id).update_all(deleted_at: Time.current, steam_id: nil)

    assert_equal :player_required, assert_nothing_written { sync(token, fixture_card_ids) }.failure
    assert_equal :player_required, assert_nothing_written { mark_private(token) }.failure
  end
end

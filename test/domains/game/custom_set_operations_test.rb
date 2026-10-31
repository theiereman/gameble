require "test_helper"
require_relative "../../support/game_packs"
require_relative "../../support/game_sets"
require_relative "../../support/custom_sets"

# Creating, renaming and deleting a player's own sets: a named list of 3 to
# 50 published games, 10 sets at most, a name unique to the player whatever
# its case; each change writes one event, a refusal writes nothing.
class Game::CustomSetOperationsTest < ActiveSupport::TestCase
  include GamePacks
  include GameSets
  include CustomSets

  setup do
    @player = accounts_players(:player)
  end

  def create(name: "Mes favoris", card_ids: fixture_card_ids.first(3), player: @player)
    Game::CreateCustomSet.new.call(player:, name:, card_ids:)
  end

  def rename(token, name, player: @player) = Game::RenameCustomSet.new.call(player:, token:, name:)

  def delete(token, player: @player) = Game::DeleteCustomSet.new.call(player:, token:)

  def writes = Game::CustomSet.count + Game::CustomSetGame.count + Rails.configuration.event_store.read.count

  def assert_refused(code, &operation)
    assert_no_difference -> { writes } do
      assert_equal code, operation.call.failure
    end
  end

  test "a set of three published games is created with its games in their order and one event" do
    ids = fixture_card_ids.values_at(2, 0, 4)

    custom_set = create(name: "  Mes   favoris ", card_ids: ids).value!

    assert_equal [ "Mes favoris", "custom", @player.id ], [ custom_set.name, custom_set.kind, custom_set.player_id ]
    assert_match(/\A[1-9A-HJ-NP-Za-km-z]{24}\z/, custom_set.token)
    assert_equal ids, Game::CustomSetGame.where(custom_set_id: custom_set.id).order(:id).pluck(:card_id)
    events = game_events(@player, Game::CustomSetCreated)
    assert_equal [ { player_id: @player.id, custom_set_id: custom_set.id } ], events.map(&:data)
  end

  test "duplicate games count once" do
    custom_set = create(card_ids: fixture_card_ids.first(3) + fixture_card_ids.first(2)).value!

    assert_equal 3, Game::CustomSetGame.where(custom_set_id: custom_set.id).count
  end

  [ nil, "", "   ", 42 ].each do |name|
    test "a name #{name.inspect} is required" do
      assert_refused(:name_required) { create(name:) }
    end
  end

  test "a name of 40 characters is kept, one of 41 refused" do
    assert create(name: "é" * 40).success?
    assert_refused(:name_too_long) { create(name: "a" * 41) }
  end

  test "a name another of the player's sets holds, in any case, is refused; another player may hold it" do
    create.value!

    assert_refused(:name_taken) { create(name: "MES FAVORIS") }
    assert create(name: "Mes favoris", player: accounts_players(:moderator)).success?
  end

  test "two games, or fifty-one counted once, are refused; fifty are kept" do
    _season, card_season_ids = published_cards(51)
    ids = Catalog::CardSeason.where(id: card_season_ids).order(:id).pluck(:card_id)

    assert_refused(:too_few_games) { create(card_ids: fixture_card_ids.first(2) * 2) }
    assert_refused(:too_many_games) { create(card_ids: ids) }
    assert create(card_ids: ids.first(50) + ids.first(3)).success?
  end

  test "a name made of invisible or control characters is required; other spaces become plain ones" do
    [ "\u0000", "\u200B\u200D", "\u00A0\u2800" ].each { |name| assert_refused(:name_required) { create(name:) } }

    assert_equal "Mes favoris", create(name: "Mes\u00A0\u200Bfavoris\u0000").value!.name
  end

  test "a name of combining marks alone is required" do
    assert_refused(:name_required) { create(name: "\u0301\u0301") }
  end

  test "a name is compared in its composed form, so an accent typed as a combining mark is the same name" do
    create(name: "Mes favorés").value!

    assert_refused(:name_taken) { create(name: "Mes favore\u0301s") }
  end

  test "the library set does not count among the ten" do
    Game::CustomSet.create!(player_id: @player.id, kind: Game::CustomSet::STEAM_LIBRARY)
    9.times { create(name: "Set #{it}").value! }

    assert create(name: "Set 9").success?
    assert_refused(:too_many_sets) { create(name: "Set 10") }
  end

  test "an eleventh set is refused" do
    10.times { create(name: "Set #{it}").value! }

    assert_refused(:too_many_sets) { create(name: "Set 10") }
  end

  test "a game unknown, or with no rated card-season in a published season, is refused" do
    draft = Catalog::Season.create!(number: Catalog::Season.next_number)
    unpublished = Catalog::Card.create!(source_key: "src:901", release_date: Date.new(2000, 1, 1),
      image_url: "https://images.example.test/901.jpg", store_url: "https://store.example.test/901")
    Catalog::CardSeason.create!(card: unpublished, season: draft, prestige_score: 0.5, rating: 80, rarity: :rare, number: 1)

    assert_refused(:game_not_in_catalog) { create(card_ids: fixture_card_ids.first(2) + [ unpublished.id ]) }
    assert_refused(:game_not_in_catalog) { create(card_ids: fixture_card_ids.first(2) + [ -1 ]) }
    assert_refused(:game_not_in_catalog) { create(card_ids: fixture_card_ids.first(2) + [ nil ]) }
  end

  test "no player, an unsaved, a banned or a deleted one is refused by every operation" do
    token = create.value!.token
    deleted = accounts_players(:moderator)
    deleted.update_columns(deleted_at: Time.current, steam_id: nil)

    [ nil, Accounts::Player.new, accounts_players(:banned), deleted ].each do |player|
      assert_refused(:player_required) { create(player:) }
      assert_refused(:player_required) { rename(token, "Autre", player:) }
      assert_refused(:player_required) { delete(token, player:) }
    end
  end

  test "a rename keeps the games, writes one event, and may keep the set's own name in another case" do
    custom_set = create.value!

    assert_equal "Jeux du soir", rename(custom_set.token, " Jeux du soir ").value!.name
    assert rename(custom_set.token, "JEUX DU SOIR").success?

    assert_equal "JEUX DU SOIR", custom_set.reload.name
    assert_equal 3, Game::CustomSetGame.where(custom_set_id: custom_set.id).count
    assert_equal [ { player_id: @player.id, custom_set_id: custom_set.id } ] * 2, game_events(@player, Game::CustomSetRenamed).map(&:data)
  end

  test "a rename to another set's name, blank or too long is refused" do
    create(name: "Autre").value!
    token = create.value!.token

    assert_refused(:name_taken) { rename(token, "autre") }
    assert_refused(:name_required) { rename(token, " ") }
    assert_refused(:name_too_long) { rename(token, "a" * 41) }
    assert_equal "Mes favoris", Game::CustomSet.find_by!(token:).name
  end

  test "another player's set, a library set or an unknown token is not found by a rename or a delete" do
    theirs = create(player: accounts_players(:moderator)).value!.token
    library = Game::CustomSet.create!(player_id: @player.id, kind: Game::CustomSet::STEAM_LIBRARY).token

    [ theirs, library, "1" * 24, nil, 42 ].each do |token|
      assert_refused(:custom_set_not_found) { rename(token, "Autre") }
      assert_refused(:custom_set_not_found) { delete(token) }
    end
  end

  test "a delete erases the set and its games, writes one event and returns the set's name" do
    custom_set = create.value!
    kept = create(name: "Autre").value!

    assert_equal "Mes favoris", delete(custom_set.token).value!

    assert_not Game::CustomSet.exists?(custom_set.id)
    assert_not Game::CustomSetGame.exists?(custom_set_id: custom_set.id)
    assert Game::CustomSetGame.exists?(custom_set_id: kept.id)
    assert_equal [ { player_id: @player.id, custom_set_id: custom_set.id } ], game_events(@player, Game::CustomSetDeleted).map(&:data)
  end

  test "every refusal has a message in both locales" do
    %i[name_required name_too_long name_taken too_few_games too_many_games too_many_sets game_not_in_catalog custom_set_not_found].each do |code|
      %i[en fr].each do |locale|
        assert_not I18n.with_locale(locale) { Game::CreateCustomSet.failure_message(code) }.start_with?("Translation missing"), "#{code} in #{locale}"
        assert I18n.exists?(Game::CreateCustomSet.failure_key(code), locale), "#{code} in #{locale}"
      end
    end
    assert_equal "Nom déjà pris : un autre de vos sets porte ce nom.", I18n.with_locale(:fr) { Game::CreateCustomSet.failure_message(:name_taken) }
  end

  test "the database holds one library set per player, a custom set's name to 40 characters and no sync state on a custom set" do
    Game::CustomSet.create!(player_id: @player.id, kind: Game::CustomSet::STEAM_LIBRARY)
    custom = create.value!

    refused = lambda do |error, &write|
      assert_raises(error) { ApplicationRecord.transaction(requires_new: true, &write) }
    end
    refused.call(ActiveRecord::RecordNotUnique) { Game::CustomSet.create!(player_id: @player.id, kind: Game::CustomSet::STEAM_LIBRARY) }
    refused.call(ActiveRecord::StatementInvalid) { Game::CustomSet.where(id: custom.id).update_all(name: nil) }
    refused.call(ActiveRecord::StatementInvalid) { Game::CustomSet.where(id: custom.id).update_all(name: "a" * 41) }
    refused.call(ActiveRecord::StatementInvalid) { Game::CustomSet.where(id: custom.id).update_all(synced_at: Time.current) }
    refused.call(ActiveRecord::RecordNotUnique) { Game::CustomSetGame.insert_all!([ { custom_set_id: custom.id, card_id: fixture_card_ids.first } ]) }
  end
end

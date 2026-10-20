require "test_helper"
require_relative "../../support/game_packs"

# Adding a held card to the player's profile showcase: at the end, five at
# most, once each, and only a card they hold.
class Game::AddToShowcaseTest < ActiveSupport::TestCase
  include GamePacks

  setup do
    @player = accounts_players(:player)
    @cards = fixture_tier_ids
  end

  def hold(card_season_id, quantity = 1, reserved: 0, player: @player)
    Game::Holding.create!(player_id: player.id, card_season_id:, quantity:, reserved:)
  end

  def add(card_season_id, player: @player)
    Game::AddToShowcase.new.call(player:, card_season_id:)
  end

  def second_edition
    season = Catalog::Season.create!(status: :draft, number: Catalog::Season.next_number)
    Catalog::CardSeason.insert_all!([ { card_id: catalog_cards(:portal).id, season_id: season.id, prestige_score: 0.5, rating: 80.0 } ],
      returning: :id).rows.flatten.sole
  end

  def chosen = Game::ChosenShowcase.call(@player)

  def writes = Game::ShowcaseEntry.count + Rails.configuration.event_store.read.count

  test "a held card joins at the end of the showcase, with one event" do
    @cards.first(3).each { hold(it) }
    add(@cards[0]).value!
    add(@cards[1]).value!

    result = add(@cards[2])

    assert result.success?
    assert_equal @cards.first(3), chosen
    assert_equal [ 0, 1, 2 ], Game::ShowcaseEntry.where(player_id: @player.id).order(:position).pluck(:position)
    event = game_events(@player, Game::ShowcaseCardAdded).last
    assert_equal({ player_id: @player.id, card_season_id: @cards[2] }, event.data)
    assert_equal 3, game_events(@player, Game::ShowcaseCardAdded).size
  end

  test "a sixth card is refused while five are showcased, with the showcase-full line" do
    @cards.each { hold(it); add(it).value! }
    sixth = second_edition
    hold(sixth)

    assert_no_difference -> { writes } do
      assert_equal :showcase_full, add(sixth).failure
    end
    assert_equal "Showcase full: remove a card to add another.", I18n.with_locale(:en) { Game::AddToShowcase.failure_message(:showcase_full) }
    assert_equal "Vitrine pleine : retirez une carte pour en ajouter une autre.",
      I18n.with_locale(:fr) { Game::AddToShowcase.failure_message(:showcase_full) }
  end

  test "a card not held, or held by someone else, is refused" do
    hold(@cards[0], 0)
    hold(@cards[1], player: accounts_players(:moderator))

    assert_no_difference -> { writes } do
      assert_equal :card_not_owned, add(@cards[0]).failure
      assert_equal :card_not_owned, add(@cards[1]).failure
      assert_equal :card_not_owned, add(@cards[2]).failure
    end
  end

  test "copies all promised to a trade still count as held" do
    hold(@cards[0], 2, reserved: 2)

    assert add(@cards[0]).success?
  end

  test "a card already showcased is refused" do
    hold(@cards[0])
    add(@cards[0]).value!

    assert_no_difference -> { writes } do
      assert_equal :card_already_showcased, add(@cards[0]).failure
    end
  end

  test "a visitor, a banned or a deleted player is refused" do
    hold(@cards[0])

    assert_no_difference -> { writes } do
      assert_equal :player_required, add(@cards[0], player: nil).failure
      assert_equal :player_required, add(@cards[0], player: accounts_players(:banned)).failure
      @player.update!(deleted_at: Time.current, steam_id: nil)
      assert_equal :player_required, add(@cards[0]).failure
    end
  end
end

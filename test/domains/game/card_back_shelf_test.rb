require "test_helper"
require_relative "../../support/game_sets"

class Game::CardBackShelfTest < ActiveSupport::TestCase
  include GameSets

  setup do
    @player = accounts_players(:player)
  end

  def shelf = Game::CardBackShelf.call(@player)
  def row(key) = shelf.find { it.key == key }
  def states = shelf.to_h { [ it.key, it.state ] }

  test "a new account has Standard active and every other back locked" do
    assert_equal Game::CardBacks::KEYS, shelf.map(&:key)
    assert_equal :active, states["standard"]
    assert_equal [ :locked ], states.except("standard").values.uniq
  end

  test "an unlocked back is offered and the chosen one is active" do
    Game::CardBackUnlock.record(@player.id, "set-theme-rpg", Time.current)

    assert_equal :unlocked, states["set-theme-rpg"]

    Game::ChooseCardBack.new.call(player: @player, back: "set-theme-rpg").value!

    assert_equal [ :active, :unlocked ], states.values_at("set-theme-rpg", "standard")
  end

  test "each row carries the unlock of the catalogue" do
    rpg = row("set-theme-rpg")

    assert_equal [ :set_tier, [ "theme", "rpg" ] ], [ rpg.unlock.kind, rpg.unlock.target ]
    assert_predicate rpg, :locked?
  end

  test "each back sits in its group, the groups in their order and the catalogue's order kept inside each" do
    groups = shelf.group_by(&:group)

    assert_equal Game::CardBackShelf::GROUPS, groups.keys.sort_by { Game::CardBackShelf::GROUPS.index(it) }
    assert_equal %w[standard saison-1 millesime-2017 soldes-hiver], groups[:base].map(&:key)
    assert_equal %w[centurion etoile-dor aurore trefle-fane assidu siege-social contrat], groups[:achievement].map(&:key)
    assert_equal %w[confrere], groups[:goal].map(&:key)
    assert_equal Game::CardBacks::THEME_KEYS.map { "set-theme-#{it}" }, groups[:theme].map(&:key)
    assert_equal Game::CardBacks::HALL_OF_FAME_KEYS.map { "set-hall_of_fame-#{it}" }, groups[:hall_of_fame].map(&:key)
  end

  test "an unlocked back carries the time it was unlocked, Standard none" do
    unlocked_at = Time.zone.local(2026, 10, 24, 18, 30)
    Game::CardBackUnlock.record(@player.id, "centurion", unlocked_at)

    assert_equal unlocked_at, row("centurion").unlocked_at
    assert_nil row("standard").unlocked_at
  end

  test "the goal back names the week of the player's first goal reward" do
    Game::CardBackUnlock.record(@player.id, "confrere", Time.current)
    [ Date.new(2026, 10, 19), Date.new(2026, 10, 12) ].each { Game::GoalReward.create!(player_id: @player.id, week_start: it) }

    assert_equal Date.new(2026, 10, 12), row("confrere").week
    assert_nil row("centurion").week
  end

  test "an earned set back carries every season it was earned in and the back tier of the latest" do
    later = Catalog::Season.create!(status: :published, number: 2, published_at: Time.current)
    first = insert_set([], { novice: 1, apprentice: 2, adept: 3, complete: 5 }, key: "roguelike", season: catalog_seasons(:one))
    second = insert_set([], { novice: 1, adept: 2, expert: 3, complete: 5 }, key: "roguelike", season: later)
    { first => "adept", second => "expert" }.each do |set_id, tier|
      Game::SetTier.create!(player_id: @player.id, set_id:, tier:, reached_by: "trade", reached_at: Time.current)
    end
    Game::CardBackUnlock.record(@player.id, "set-theme-roguelike", Time.current)

    roguelike = row("set-theme-roguelike")

    assert_equal [ [ 1, 2 ], "expert" ], [ roguelike.seasons, roguelike.tier ]
    assert_nil roguelike.progress
  end

  test "a locked set back counts the cards held in the published season against its back tier" do
    members = [ catalog_card_seasons(:common_card_one).id, catalog_card_seasons(:rare_card_one).id, *unheld_cards(2) ]
    insert_set(members, { bronze: 1, silver: 2, complete: 4 }, key: "horror")
    Game::Holding.create!(player_id: @player.id, card_season_id: members.first, quantity: 1)

    progress = row("set-theme-horror").progress

    assert_equal [ 1, 4, 2, 1 ], [ progress.held, progress.total, progress.required, progress.missing ]
  end

  test "a locked set back whose set is not in the published season has no progress" do
    insert_set([], { complete: 4 }, key: "horror", season: Catalog::Season.create!(status: :draft, number: 2))

    assert_nil row("set-theme-horror").progress
    assert_nil row("set-theme-rpg").progress
  end
end

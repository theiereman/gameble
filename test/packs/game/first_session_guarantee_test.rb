require "test_helper"
require_relative "../../support/game_packs"

# The first-session guarantee (R3): a sapphire or better by the tenth pack,
# forced into the tenth only when the first nine have none.
class Game::FirstSessionGuaranteeTest < ActiveSupport::TestCase
  include GamePacks

  setup do
    Game::DrawPool.reset!
    @pool = Game::DrawPool.current
    @steel, @emerald, @sapphire, @amethyst, @gold = fixture_tier_ids
  end

  def rare?(cards) = cards.any? { |id| @pool.tier_of(id) >= 3 }

  test "the guarantee odds sum to the total" do
    assert_equal Game::DrawOdds::TOTAL, Game::DrawOdds::GUARANTEE.values.sum
  end

  test "every one of 2,000 seeded first fills holds a sapphire or better in its first ten packs" do
    random = Random.new(20_261_002)

    2_000.times do
      draws = Array.new(10) { Game::Draw.pack(odds: Game::DrawOdds::REGULAR, size: 5, random:, pool: @pool) }
      packs = Game::FirstSessionGuarantee.apply(draws, pool: @pool, random:)

      assert packs.any? { |cards| rare?(cards) }
    end
  end

  test "a sapphire in the first nine packs leaves the tenth as drawn" do
    draws = Array.new(10) { Array.new(5, @steel) }
    draws[3][2] = @sapphire

    assert_equal draws, Game::FirstSessionGuarantee.apply(draws, pool: @pool, random: Random.new(1))
  end

  test "a rare card already in the tenth pack is kept as drawn" do
    draws = Array.new(10) { Array.new(5, @emerald) }
    draws[9][4] = @gold

    assert_equal draws, Game::FirstSessionGuarantee.apply(draws, pool: @pool, random: Random.new(1))
  end

  test "with no rare card in the first nine packs, one card of the tenth is replaced and the other 49 are unchanged" do
    draws = Array.new(10) { Array.new(5, @steel) }

    packs = Game::FirstSessionGuarantee.apply(draws, pool: @pool, random: Random.new(7))

    assert_equal draws.first(9), packs.first(9)
    changed = packs[9].each_index.reject { |index| packs[9][index] == @steel }
    assert_equal 1, changed.size
    assert_operator @pool.tier_of(packs[9][changed.first]), :>=, 3
    assert_equal Array.new(10) { Array.new(5, @steel) }, draws, "the input is not changed"
  end

  test "the forced card's tier follows 86 %, 13 % and 1 % within 4 standard deviations" do
    random = Random.new(42)
    draws = Array.new(10) { Array.new(5, @steel) }
    n = 20_000
    counts = Hash.new(0)

    n.times do
      tenth = Game::FirstSessionGuarantee.apply(draws, pool: @pool, random:)[9]
      counts[@pool.tier_of(tenth.find { |id| id != @steel })] += 1
    end

    { 3 => 0.86, 4 => 0.13, 5 => 0.01 }.each do |tier, share|
      sigma = Math.sqrt(n * share * (1 - share))
      assert_in_delta n * share, counts[tier], 4 * sigma, "tier #{tier}"
    end
  end

  test "FillBank applies the guarantee: with all-steel draws, the tenth pack in opening order gets the forced card" do
    player = accounts_players(:player)
    steel = @steel

    original = Game::Draw.method(:pack)
    Game::Draw.define_singleton_method(:pack) { |**| Array.new(5, steel) }
    begin
      Game::FillBank.new(random: Random.new(3)).call(player:)
    ensure
      Game::Draw.define_singleton_method(:pack, original)
    end

    packs = Game::Pack.where(player_id: player.id).order(:available_at, :id).map(&:card_season_ids)
    assert_equal 10, packs.size
    assert packs.first(9).none? { |cards| rare?(cards) }
    assert rare?(packs[9]), "the tenth pack holds the forced card"
  end
end

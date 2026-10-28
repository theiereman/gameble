require "test_helper"
require_relative "../../support/game_packs"

# Game::CollectDailyBonus: once per UTC day, a bonus
# pack of three cards with better odds, outside the bank's cap of ten,
# opened in arrival order, never refused for a full reserve: it joins the
# special reserve; and the bank summary's `bonus_collectable` and `special`.
class Game::CollectDailyBonusTest < ActiveSupport::TestCase
  include GamePacks

  setup do
    @player = accounts_players(:player)
    @now = Time.utc(2026, 10, 2, 15, 0)
  end

  def collect(player = @player) = Game::CollectDailyBonus.new.call(player:)
  def packs = Game::Pack.where(player_id: @player.id)
  def claims = Game::DailyBonusClaim.where(player_id: @player.id)
  def summary(now = Time.current) = Game::BankSummary.call(@player, now:)

  def full_bank
    Game::FillBank.new.call(player: @player).value!
  end

  # A full bank with one pack opened: nine available, the replacement ten
  # minutes after the opening.
  def reserve_of_nine
    full_bank
    Game::OpenPack.new.call(player: @player).value!
  end

  def unpublish
    catalog_seasons(:one).update_columns(status: "draft", published_at: nil)
  end

  test "collecting with a reserve of nine: one claim, a bonus pack of three available now, one event; the standard reserve stays nine" do
    travel_to(@now) do
      reserve_of_nine

      result = collect

      assert result.success?
      pack = result.value!
      assert_predicate pack, :bonus?
      assert_equal @now, pack.available_at
      assert_nil pack.opened_at
      assert_equal catalog_seasons(:one).id, pack.season_id
      assert_equal Game::Pack::BONUS_SIZE, pack.card_season_ids.size
      assert_empty pack.card_season_ids - fixture_tier_ids
      assert_not_includes pack.card_season_ids, catalog_card_seasons(:common_card_one).id
      claim = claims.sole
      assert_equal Date.new(2026, 10, 2), claim.day
      assert_equal pack.id, claim.pack_id
      events = game_events(@player, Game::DailyBonusCollected)
      assert_equal 1, events.size
      assert_equal({ player_id: @player.id, pack_id: pack.id }, events.sole.data)
      assert_equal 10, Game::Pack.bank(@player.id).count
      assert_equal({ available: 9, special: 1, openable: 10, reserve_full: false, next_available_at: @now + 10.minutes,
                    bonus_collectable: false, bonus_collected: true, next_bonus_at: Time.utc(2026, 10, 3) }, summary)
    end
  end

  test "a full standard reserve does not refuse the bonus: it joins the special reserve" do
    travel_to(@now) do
      full_bank
      assert summary[:reserve_full]
      assert summary[:bonus_collectable]

      assert collect.success?

      assert_equal 1, claims.count
      assert_equal 1, packs.bonus.count
      assert_equal 10, packs.regular.count
      assert_equal 1, game_events(@player, Game::DailyBonusCollected).size
      assert_equal({ available: 10, special: 1, openable: 11, reserve_full: true }, summary.slice(:available, :special, :openable, :reserve_full))
    end
  end

  test "the reserve counts available standard packs and the special reserve apart; scheduled and opened ones are in neither" do
    travel_to(@now) do
      7.times { create_pack(@player, available_at: @now - 1.minute) }
      create_pack(@player, available_at: @now - 1.minute, kind: :bonus)
      create_pack(@player, available_at: @now + 1.minute)
      create_pack(@player, available_at: @now - 1.minute, opened_at: @now - 1.minute)
      counts = Game::Reserve.counts(@player.id, now: @now)
      assert_equal [ 7, 1, 8 ], [ counts.standard, counts.special, counts.openable ]

      create_pack(@player, available_at: @now - 1.minute, kind: :reward)
      assert_equal 2, Game::Reserve.counts(@player.id, now: @now).special
      assert collect.success?

      counts = Game::Reserve.counts(@player.id, now: @now)
      assert_equal [ 7, 3, 10 ], [ counts.standard, counts.special, counts.openable ]
    end
  end

  test "an already collected bonus is refused as such, even with a full reserve" do
    travel_to(@now) do
      full_bank
      collect.value!
      assert summary[:reserve_full]

      assert_equal :already_collected, collect.failure
    end
  end

  test "a player without a bank gets ten regular packs with the guarantee, then the bonus" do
    travel_to(@now) { collect.value! }

    assert_equal 10, packs.regular.count
    assert_equal 1, packs.bonus.count
    pool = Game::DrawPool.current
    regular = packs.regular.order(:available_at, :id).map(&:card_season_ids)
    assert regular.any? { |cards| cards.any? { |id| pool.tier_of(id) >= Game::FirstSessionGuarantee::MIN_TIER } }
    assert_equal [ Game::BankFilled, Game::DailyBonusCollected ], game_events(@player).map(&:class)
    assert_equal packs.bonus.sole, packs.available(@now).last
  end

  test "on a running clock, a new bank's ten packs still open before the bonus" do
    collect.value!

    assert_equal packs.bonus.sole, packs.available(Time.current).last
    assert_equal 10, packs.available(Time.current).regular.count
  end

  test "a second collection the same UTC day writes nothing and publishes nothing" do
    travel_to(@now) { collect.value! }

    result = travel_to(@now + 8.hours + 59.minutes) { collect }

    assert_equal :already_collected, result.failure
    assert_equal 1, claims.count
    assert_equal 1, packs.bonus.count
    assert_equal 1, game_events(@player, Game::DailyBonusCollected).size
  end

  test "the database refuses a second claim for the same player and day" do
    pack = travel_to(@now) { collect.value! }

    assert_raises(ActiveRecord::RecordNotUnique) do
      Game::DailyBonusClaim.create!(player_id: @player.id, day: Date.new(2026, 10, 2), pack_id: pack.id)
    end
  end

  test "the day is the UTC day, whatever the time zone: 23:59:59 then 00:00:01 are two days" do
    Time.use_zone("Pacific/Kiritimati") do
      travel_to(Time.utc(2026, 10, 2, 23, 59, 59)) do
        collect.value!
        # Ten packs and the bonus: two openings bring the reserve under ten.
        2.times { Game::OpenPack.new.call(player: @player).value! }
      end

      result = travel_to(Time.utc(2026, 10, 3, 0, 0, 1)) { collect }

      assert result.success?
    end
    assert_equal [ Date.new(2026, 10, 2), Date.new(2026, 10, 3) ], claims.order(:day).pluck(:day)
  end

  test "a bank that is not full keeps its next pack" do
    8.times { create_pack(@player, available_at: @now - 1.minute) }
    create_pack(@player, available_at: @now + 4.minutes)
    create_pack(@player, available_at: @now + 14.minutes)

    travel_to(@now) do
      collect.value!

      assert_equal({ available: 8, special: 1, openable: 9, reserve_full: false, next_available_at: @now + 4.minutes,
                    bonus_collectable: false, bonus_collected: true, next_bonus_at: Time.utc(2026, 10, 3) }, summary)
      assert_equal 10, Game::Pack.bank(@player.id).count
    end
  end

  test "the bonus opens after the packs already available, and opening it inserts no regular pack" do
    travel_to(@now) do
      3.times { |index| create_pack(@player, available_at: @now - (3 - index).minutes) }
      bonus = collect.value!

      opened = Array.new(3) { Game::OpenPack.new.call(player: @player).value! }
      assert opened.all?(&:regular?)
      regular = packs.regular.count

      assert_equal bonus, Game::OpenPack.new.call(player: @player).value!
      assert_equal regular, packs.regular.count
    end
  end

  test "bonuses of several days are never refused, whatever the standard reserve holds" do
    travel_to(@now) do
      full_bank
      collect.value!
    end

    travel_to(@now + 1.day) do
      collect.value!

      assert_equal 2, packs.bonus.count
      assert_equal({ available: 10, special: 2, openable: 12, reserve_full: true, next_available_at: nil, bonus_collectable: false,
                    bonus_collected: true, next_bonus_at: Time.utc(2026, 10, 4) }, summary)
    end
  end

  test "with no season published: no claim, no pack, and the bonus can be collected later that day" do
    unpublish
    travel_to(@now) do
      assert_not summary[:bonus_collectable]

      assert_equal :no_season, collect.failure
      assert_equal 0, claims.count
      assert_equal 0, packs.count
      assert_empty game_events(@player)
    end

    catalog_seasons(:one).update_columns(status: "published", published_at: @now)
    travel_to(@now + 1.hour) do
      assert summary[:bonus_collectable]
      assert collect.success?
    end
  end

  test "a missing or banned player fails with player_required and nothing is written" do
    [ nil, accounts_players(:banned) ].each do |player|
      assert_equal :player_required, collect(player).failure
    end
    assert_equal 0, Game::DailyBonusClaim.count
    assert_equal 0, Game::Pack.count
  end

  test "the bonus is collectable again the next UTC day" do
    travel_to(@now) { collect.value! }

    assert_not summary(@now.end_of_day)[:bonus_collectable]
    assert summary(@now.end_of_day + 1.second)[:bonus_collectable]
  end
end

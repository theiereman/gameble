require "active_support/testing/time_helpers"

class EconomyHistorySeed
  include ActiveSupport::Testing::TimeHelpers

  DAYS = 90
  PLAYERS = 12

  def initialize(today: Time.current.utc.to_date)
    @first_day = today - DAYS
    @last_day = today - 1
  end

  def call
    settings = backdate_first_opening
    player_ids = players.map(&:id)
    written = (@first_day..@last_day).count do |day|
      next false if Game::Market::DailySnapshot.exists?(day:)

      post_day(day, day_index(day), player_ids, settings.id) unless entries_on?(day)
      Game::Market::WriteDailySnapshot.new.call(day:, circulation: circulation_before(day + 1))
      true
    end
    puts "Seeded #{written} days of economy history."
  end

  private

  def players
    (1..PLAYERS).map do |number|
      Accounts::SignIn.new.call(steam_id: DevSignInsController.steam_id(number), persona_name: DevSignInsController.persona_name(number)).value!
    end
  end

  def backdate_first_opening
    current = Game::Market::CurrentSettings.call
    opened_at = @first_day.in_time_zone("UTC")
    return current if current.first_opened_at <= opened_at

    administrator = Accounts::Player.find_by!(role: :administrator)
    current.successor(author: administrator, first_opened_at: opened_at).tap(&:save!)
  end

  def day_index(day) = (day - @first_day).to_i

  def entries_on?(day) = Game::Market::LedgerEntry.where(created_at: midnight(day)...midnight(day + 1)).exists?

  def circulation_before(day) = Game::Market::LedgerEntry.where(created_at: ...midnight(day)).sum("available_delta + committed_delta")

  def midnight(day) = day.in_time_zone("UTC")

  def post_day(day, index, player_ids, settings_id)
    travel_to(midnight(day) + 12.hours) do
      ActiveRecord::Base.transaction { Game::Market::Ledger.post(day_entries(index, player_ids, settings_id)) }
    end
  end

  def day_entries(index, player_ids, settings_id)
    growth = 1 + (index / DAYS.to_f)
    player_ids.each_with_index.flat_map do |player_id, rank|
      seller_id = player_ids[(rank + 1) % player_ids.size]
      price = 8_000 + (400 * ((index * 3 + rank) % 11))
      commission = price / 10
      minted = ((24_000 + (1_000 * ((index * 7 + rank * 13) % 17))) * growth).to_i
      stamped = minted * (45 + ((index + rank) % 20)) / 100
      entry = ->(**attributes) { Game::Market::Ledger::Entry.new(settings_id:, **attributes) }
      [
        entry.call(player_id:, kind: :mint, available_delta: minted),
        entry.call(player_id:, kind: :stamp, available_delta: -stamped),
        entry.call(player_id:, kind: :purchase, available_delta: -price),
        entry.call(player_id: seller_id, kind: :sale, available_delta: price),
        entry.call(player_id: seller_id, kind: :commission, available_delta: -commission)
      ]
    end
  end
end

EconomyHistorySeed.new.call

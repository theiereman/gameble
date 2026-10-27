module Game
  class HealBanksJob < ActiveJob::Base
    queue_as :default

    BANK_COUNT = Arel.sql("COUNT(*) FILTER (WHERE kind = 'regular' AND opened_at IS NULL)")

    def perform
      season = Catalog::PublishedSeason.call
      return if season.nil?

      Accounts::PlayersInBatches.call do |players|
        packs = Pack.where(player_id: players.map(&:id)).group(:player_id)
          .pluck(:player_id, BANK_COUNT, earlier_season_count(season.id))
          .to_h { |player_id, bank, earlier| [ player_id, { bank:, earlier: } ] }
        players.each do |player|
          next if served?(packs[player.id])

          operation = packs.key?(player.id) ? HealBank : FillBank
          result = operation.new.call(player:)
          result.value! unless left_meanwhile?(result)
        rescue StandardError => error
          Rails.error.report(error, context: { player_id: player.id })
        end
      end
    end

    private

    def earlier_season_count(season_id)
      Arel.sql(Pack.sanitize_sql_array([ "COUNT(*) FILTER (WHERE opened_at IS NULL AND season_id <> ?)", season_id ]))
    end

    def served?(packs)
      packs.present? && packs.fetch(:bank) >= Pack::BANK_SIZE && packs.fetch(:earlier).zero?
    end

    def left_meanwhile?(result)
      result.failure? && result.failure == :player_required
    end
  end
end

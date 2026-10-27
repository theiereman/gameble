module Game
  # Brings every player in good standing to the published season when one is
  # published, the only moment a bank is healed: a player who never had a
  # pack gets their first ten (Game::FillBank), and a player whose bank is
  # short of ten, such as one who opened packs while no season was
  # published, or who holds an unopened pack of an earlier season, gets the
  # missing packs and the earlier ones redrawn (Game::HealBank); every new
  # pack is available at once. Each player is served in their own
  # transaction; both operations do nothing for a player served meanwhile. A
  # player whose fill fails is reported and skipped, so the others are still
  # served; nothing retries it before the next publication. A player deleted
  # since their batch was read is skipped unreported. With no published
  # season there is nothing to do.
  #
  # One query reads the published season; then per batch of players, one
  # query reads whether each had a pack, how many their bank holds and how
  # many of their unopened packs are of another season; a player whose bank
  # is full and of the published season costs nothing more.
  class HealBanksJob < ActiveJob::Base
    queue_as :default

    # Per player of the batch who ever had a pack: the packs in their bank
    # (unopened regular packs).
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

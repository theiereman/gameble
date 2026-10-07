module Game
  # Brings every player in good standing to a full bank (AD-7) when a season
  # is published, the only moment a bank is healed: a player who never had a
  # pack gets their first ten (Game::FillBank), and a player whose bank is
  # short of ten, such as one who opened packs while no season was
  # published, gets the missing ones (Game::HealBank); either way every new
  # pack is available at once. Each player is served in their own
  # transaction; both operations do nothing for a bank served meanwhile. A
  # player whose fill fails is reported and skipped, so the others still get
  # their bank; nothing retries it before the next publication.
  #
  # Per batch of players, one query reads whether each had a pack and how
  # many their bank holds; a player whose bank is full costs nothing more.
  class HealBanksJob < ActiveJob::Base
    queue_as :default

    # Per player of the batch who ever had a pack: the packs in their bank
    # (unopened regular packs).
    BANK_COUNT = Arel.sql("COUNT(*) FILTER (WHERE kind = 'regular' AND opened_at IS NULL)")

    def perform
      Accounts::PlayersInBatches.call do |players|
        banks = Pack.where(player_id: players.map(&:id)).group(:player_id).pluck(:player_id, BANK_COUNT).to_h
        players.each do |player|
          next if banks.fetch(player.id, 0) >= Pack::BANK_SIZE

          operation = banks.key?(player.id) ? HealBank : FillBank
          operation.new.call(player:).value!
        rescue StandardError => error
          Rails.error.report(error, context: { player_id: player.id })
        end
      end
    end
  end
end

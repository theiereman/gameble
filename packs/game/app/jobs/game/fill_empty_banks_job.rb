module Game
  # Brings every player in good standing to a full bank (AD-7) when a season
  # is published: a player who never had a pack gets their first ten
  # (Game::FillBank), and a player whose bank is short of ten, such as one
  # who opened their last pack while no season was published, is topped up
  # (Game::HealBank). Each player is served in their own transaction; both
  # operations do nothing for a bank served meanwhile. A player whose fill
  # fails is reported and skipped, so the others still get their bank.
  class FillEmptyBanksJob < ActiveJob::Base
    queue_as :default

    def perform
      Accounts::PlayersInBatches.call do |players|
        banked = Pack.where(player_id: players.map(&:id)).distinct.pluck(:player_id).to_set
        players.each do |player|
          operation = banked.include?(player.id) ? HealBank : FillBank
          operation.new.call(player:).value!
        rescue StandardError => error
          Rails.error.report(error, context: { player_id: player.id })
        end
      end
    end
  end
end

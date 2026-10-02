module Game
  # Fills the bank of every player in good standing who never had a pack
  # (AD-7): the players who signed up while no season was published. Each
  # player is filled in their own transaction; Game::FillBank skips anyone
  # filled meanwhile. A player whose fill fails is reported and skipped, so
  # the others still get their bank.
  class FillEmptyBanksJob < ActiveJob::Base
    queue_as :default

    def perform
      Accounts::PlayersInBatches.call do |players|
        banked = Pack.where(player_id: players.map(&:id)).distinct.pluck(:player_id).to_set
        players.reject { |player| banked.include?(player.id) }.each do |player|
          FillBank.new.call(player:).value!
        rescue StandardError => error
          Rails.error.report(error, context: { player_id: player.id })
        end
      end
    end
  end
end

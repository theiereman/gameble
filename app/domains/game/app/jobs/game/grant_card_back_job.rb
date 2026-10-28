module Game
  class GrantCardBackJob < ActiveJob::Base
    queue_as :default

    Outcome = Data.define(:granted, :already_held, :not_found, :failed)

    def self.grant(back:, steam_ids:)
      counts = { granted: 0, already_held: 0, not_found: 0, failed: 0 }
      steam_ids.each { counts[outcome(back, it)] += 1 }
      Outcome.new(**counts)
    end

    def self.outcome(back, steam_id)
      player = Accounts::PlayerBySteamId.call(steam_id)
      return :not_found if player.nil? || player.banned?

      result = UnlockCardBack.new.call(player:, back:)
      return :granted if result.success?

      result.failure == :already_unlocked ? :already_held : :failed
    rescue StandardError => error
      Rails.error.report(error, context: { steam_id: steam_id.to_s, back: })
      :failed
    end
    private_class_method :outcome

    def perform(back, steam_ids)
      self.class.grant(back:, steam_ids:)
    end
  end
end

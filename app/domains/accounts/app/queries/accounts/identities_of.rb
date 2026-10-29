module Accounts
  module IdentitiesOf
    Entry = Data.define(:provider, :created_at)

    def self.call(player)
      Identity.where(player_id: player.id).order(:created_at, :id)
        .pluck(:provider, :created_at).map { |provider, created_at| Entry.new(provider:, created_at:) }
    end
  end
end

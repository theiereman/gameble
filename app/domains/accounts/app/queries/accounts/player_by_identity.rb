module Accounts
  module PlayerByIdentity
    def self.call(provider:, uid:)
      return nil if provider.blank? || uid.blank?

      Player.find_by(id: Identity.where(provider: provider.to_s, uid: uid.to_s).select(:player_id), deleted_at: nil)
    end
  end
end

module Accounts
  module ModerationHistory
    def self.call(player = nil)
      actions = ModerationAction.includes(:player, :staff).order(created_at: :desc, id: :desc)
      player ? actions.where(player:) : actions
    end
  end
end

module Accounts
  class ModerationAction < ApplicationRecord
    self.table_name = "accounts_moderation_actions"

    enum :kind, { ban: "ban", unban: "unban", dismissal: "dismissal", erasure: "erasure" }, validate: true

    belongs_to :player, class_name: "Accounts::Player"
    belongs_to :staff, class_name: "Accounts::Player"
  end
end

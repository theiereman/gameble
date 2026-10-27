module Accounts
  class Report < ApplicationRecord
    self.table_name = "accounts_reports"

    enum :reason, {
      inappropriate_name: "inappropriate_name",
      cheating: "cheating",
      harassment: "harassment",
      other: "other"
    }, validate: true

    belongs_to :reporter, class_name: "Accounts::Player"
    belongs_to :reported, class_name: "Accounts::Player"

    scope :unhandled, -> { where(handled_at: nil) }
  end
end

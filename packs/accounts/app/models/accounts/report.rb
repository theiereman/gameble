module Accounts
  # A player's report of another player's username or profile, one per
  # reporter and reported player. The reporter is kept; the reported player
  # never learns of it. Created only by Accounts::ReportPlayer. The staff's
  # queue counts the open ones; a ban or a dismissal sets `handled_at`.
  class Report < ApplicationRecord
    self.table_name = "accounts_reports"

    # The four reasons of the report dialog (EXPERIENCE.md, Report).
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

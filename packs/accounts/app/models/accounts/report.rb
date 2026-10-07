module Accounts
  # A player's report of another player's username or profile (CAP-15,
  # AD-14). It names the reporter for the staff's queue; the reported player
  # never learns of it. Written only by Accounts::ReportPlayer.
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
  end
end

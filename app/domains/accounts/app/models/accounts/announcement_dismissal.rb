module Accounts
  class AnnouncementDismissal < ApplicationRecord
    self.table_name = "accounts_announcement_dismissals"

    belongs_to :announcement, class_name: "Accounts::Announcement", inverse_of: :dismissals
    belongs_to :player, class_name: "Accounts::Player"
  end
end

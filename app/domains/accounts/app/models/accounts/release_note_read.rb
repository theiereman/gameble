module Accounts
  class ReleaseNoteRead < ApplicationRecord
    self.table_name = "accounts_release_note_reads"

    belongs_to :release_note, class_name: "Accounts::ReleaseNote", inverse_of: :reads
    belongs_to :player, class_name: "Accounts::Player"
  end
end

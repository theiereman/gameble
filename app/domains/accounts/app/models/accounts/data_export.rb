module Accounts
  class DataExport < ApplicationRecord
    self.table_name = "accounts_data_exports"

    belongs_to :player, class_name: "Accounts::Player"
  end
end

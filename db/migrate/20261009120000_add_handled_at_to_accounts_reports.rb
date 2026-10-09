class AddHandledAtToAccountsReports < ActiveRecord::Migration[8.1]
  def change
    add_column :accounts_reports, :handled_at, :datetime
  end
end

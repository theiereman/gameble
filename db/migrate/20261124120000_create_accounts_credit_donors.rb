# The names of the donors the credits page thanks, typed in by hand: a donor does not need an account.
class CreateAccountsCreditDonors < ActiveRecord::Migration[8.1]
  def change
    create_table :accounts_credit_donors do |t|
      t.string :token, null: false, index: { unique: true }
      t.string :name, null: false
      t.timestamps

      t.index "lower(name)", unique: true, name: "index_accounts_credit_donors_on_lower_name"
      t.check_constraint "char_length(name) BETWEEN 1 AND 60", name: "accounts_credit_donors_name_length_check"
    end
  end
end

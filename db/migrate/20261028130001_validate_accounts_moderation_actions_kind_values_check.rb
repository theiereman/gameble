class ValidateAccountsModerationActionsKindValuesCheck < ActiveRecord::Migration[8.1]
  def change
    validate_check_constraint :accounts_moderation_actions, name: "accounts_moderation_actions_kind_values_check"
  end
end

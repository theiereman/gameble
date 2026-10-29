class ValidateAccountsPlayersPersonaNameLengthCheck < ActiveRecord::Migration[8.1]
  def change
    validate_check_constraint :accounts_players, name: "accounts_players_persona_name_length_check"
  end
end

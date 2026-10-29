class AddPersonaNameLengthCheckToAccountsPlayers < ActiveRecord::Migration[8.1]
  def change
    add_check_constraint :accounts_players, "persona_name IS NULL OR char_length(persona_name) <= 512",
      name: "accounts_players_persona_name_length_check", validate: false
  end
end

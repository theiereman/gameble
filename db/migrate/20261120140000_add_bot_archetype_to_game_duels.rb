# The kind of deck the practice bot was dealt; nil for a duel between two players.
class AddBotArchetypeToGameDuels < ActiveRecord::Migration[8.1]
  def change
    add_column :game_duels, :bot_archetype, :string
    add_check_constraint :game_duels,
      "bot_archetype IS NULL OR bot_archetype::text = 'coverage'::text OR bot_archetype::text = 'popularity'::text " \
      "OR bot_archetype::text = 'rating'::text OR bot_archetype::text = 'release'::text OR bot_archetype::text = 'discovery'::text " \
      "OR bot_archetype::text = 'circulation'::text OR bot_archetype::text = 'two_stats'::text OR bot_archetype::text = 'trumps'::text " \
      "OR bot_archetype::text = 'random'::text",
      name: "game_duels_bot_archetype_check", validate: false
  end
end

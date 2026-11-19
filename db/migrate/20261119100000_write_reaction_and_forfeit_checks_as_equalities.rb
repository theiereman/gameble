# PostgreSQL stores `column IN (...)` on a varchar column in a form that db/schema.rb does not round-trip.
class WriteReactionAndForfeitChecksAsEqualities < ActiveRecord::Migration[8.1]
  REACTION_KINDS = %w[thumb heart gg wow middle_finger poop want].freeze
  FORFEITING_SEATS = %w[challenger opponent].freeze

  def change
    remove_check_constraint :game_feed_reactions, "kind IN (#{quoted(REACTION_KINDS)})", name: "game_feed_reactions_kind_check"
    add_check_constraint :game_feed_reactions, equalities(:kind, REACTION_KINDS), name: "game_feed_reactions_kind_check", validate: false

    remove_check_constraint :game_duels, "forfeited_by IS NULL OR (state = 'finished' AND forfeited_by IN (#{quoted(FORFEITING_SEATS)}))",
      name: "game_duels_forfeited_by_check"
    add_check_constraint :game_duels,
      "forfeited_by IS NULL OR state::text = 'finished'::text AND (#{equalities(:forfeited_by, FORFEITING_SEATS)})",
      name: "game_duels_forfeited_by_check", validate: false
  end

  private

  def quoted(values) = values.map { "'#{it}'" }.join(", ")

  def equalities(column, values) = values.map { "#{column}::text = '#{it}'::text" }.join(" OR ")
end

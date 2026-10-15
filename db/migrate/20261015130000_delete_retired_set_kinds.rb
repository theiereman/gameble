class DeleteRetiredSetKinds < ActiveRecord::Migration[8.1]
  RETIRED_SETS = "SELECT id FROM catalog_sets WHERE kind = 'tome' OR kind = 'publisher' OR kind = 'best_of_year'".freeze

  def up
    safety_assured do
      execute "DELETE FROM game_set_completions WHERE set_id IN (#{RETIRED_SETS})"
      execute "DELETE FROM catalog_set_memberships WHERE set_id IN (#{RETIRED_SETS})"
      execute "DELETE FROM catalog_set_tiers WHERE set_id IN (#{RETIRED_SETS})"
      execute "DELETE FROM catalog_sets WHERE id IN (#{RETIRED_SETS})"
    end
  end

  def down
    raise ActiveRecord::IrreversibleMigration
  end
end

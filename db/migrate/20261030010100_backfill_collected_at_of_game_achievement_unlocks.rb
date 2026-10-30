class BackfillCollectedAtOfGameAchievementUnlocks < ActiveRecord::Migration[8.1]
  disable_ddl_transaction!

  BATCH_SIZE = 10_000

  def up
    after_id = 0
    while (last_id = collect_batch_after(after_id))
      after_id = last_id
    end
  end

  def down
  end

  private

  def collect_batch_after(after_id)
    ids = select_values("SELECT id FROM game_achievement_unlocks WHERE id > #{Integer(after_id)} ORDER BY id LIMIT #{BATCH_SIZE}")
    return if ids.empty?

    safety_assured do
      execute <<~SQL.squish
        UPDATE game_achievement_unlocks
        SET collected_at = unlocked_at
        WHERE id >= #{Integer(ids.first)} AND id <= #{Integer(ids.last)} AND collected_at IS NULL
      SQL
    end
    ids.last
  end
end

class StartExistingPlayersAtThePublishedSeason < ActiveRecord::Migration[8.1]
  disable_ddl_transaction!

  BATCH_SIZE = 10_000

  def up
    published = select_value("SELECT MAX(number) FROM catalog_seasons WHERE status = 'published'")
    return if published.nil?

    after_id = 0
    while (last_id = start_batch_after(after_id, Integer(published)))
      after_id = last_id
    end
  end

  def down
  end

  private

  def start_batch_after(after_id, published)
    ids = select_values("SELECT id FROM game_player_states WHERE id > #{Integer(after_id)} ORDER BY id LIMIT #{BATCH_SIZE}")
    return if ids.empty?

    safety_assured do
      execute <<~SQL.squish
        UPDATE game_player_states
        SET allocation_received_season = #{published}, allocation_seen_season = #{published}
        WHERE id >= #{Integer(ids.first)} AND id <= #{Integer(ids.last)}
          AND allocation_received_season IS NULL AND allocation_seen_season IS NULL
      SQL
    end
    ids.last
  end
end

# The genres step of the Steam import is removed (story 2.10): a card's
# genres now come from the tags the details step stores. A run left on that
# step (failed, or stopped mid-way) moves to the cards step, cursor 0, so a
# resume writes its cards. A run still running on that step keeps a queued
# job whose genres cursor no longer matches: it stops, and the run waits for
# Steam::RecoverStalledImportsJob (10 minutes without moving) to enqueue its
# cards page. Data only; the genres columns stay until a later
# contract migration. Irreversible: down leaves the runs on the cards step.
class MoveImportRunsOffTheGenresStep < ActiveRecord::Migration[8.1]
  # An UPDATE of the few runs on that step: no schema change, no long lock.
  def up
    safety_assured do
      execute <<~SQL.squish
        UPDATE steam_import_runs
        SET step = 'cards', cursor = '{"step": "cards", "last_appid": 0}'::jsonb, updated_at = CURRENT_TIMESTAMP
        WHERE step = 'genres'
      SQL
    end
  end

  def down
  end
end

# Steam's store tags, named in English, from
# IStoreService/GetTagList. Upserted on tagid by every import run's tags step.
# Labels in other languages come later.
class CreateSteamTags < ActiveRecord::Migration[8.1]
  def change
    create_table :steam_tags do |t|
      t.bigint :tagid, null: false
      t.string :name, null: false
      t.timestamps
    end
    add_index :steam_tags, :tagid, unique: true
  end
end

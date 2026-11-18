class CreateGameFeatureFlags < ActiveRecord::Migration[8.1]
  def change
    create_table :game_feature_flags do |t|
      t.string :key, null: false
      t.boolean :enabled, null: false, default: false
      t.timestamps
      t.index :key, unique: true
    end
  end
end

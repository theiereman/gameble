class AddPoopAndWantToGameFeedReactionsKinds < ActiveRecord::Migration[8.1]
  def change
    remove_check_constraint :game_feed_reactions,
      "kind::text = 'thumb'::text OR kind::text = 'heart'::text OR kind::text = 'gg'::text OR kind::text = 'wow'::text OR kind::text = 'middle_finger'::text",
      name: "game_feed_reactions_kind_check"
    add_check_constraint :game_feed_reactions, "kind IN ('thumb', 'heart', 'gg', 'wow', 'middle_finger', 'poop', 'want')",
      name: "game_feed_reactions_kind_check", validate: false
  end
end

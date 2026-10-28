# Gives a player an earned profile title and, optionally, makes it their
# active one: the Adept rank of the fixture Valve studio set.
module ActiveTitles
  ACTIVE_TITLE_TEXT = "Adept · Valve".freeze

  def earn_title(player, equip: true)
    set_id = valve_set_id
    Game::SetTier.insert_all!([ { player_id: player.id, set_id:, tier: "silver", reached_by: "trade", reached_at: Time.current } ])
    Game::ChooseProfileTitle.new.call(player:, rank: "adept", kind: "studio", key: "valve").value! if equip
  end

  def valve_set_id = catalog_sets(:valve_one).id
end

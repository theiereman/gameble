module GrandInventoriesHelper
  def grand_inventory_seasons(inventory) = ("current" if inventory.scope == :current)

  def grand_inventory_count_words(inventory)
    t("grand_inventories.show.count.spoken", count: inventory.found_count, found: number_with_delimiter(inventory.found_count),
      total: number_with_delimiter(inventory.total))
  end

  def grand_inventory_scope_status(inventory)
    t("grand_inventories.show.scopes.status.#{inventory.scope}", count: grand_inventory_count_words(inventory))
  end

  def grand_inventory_mine?(discovery)
    current_player.present? && discovery&.player == current_player
  end

  def grand_inventory_card_label(view, discovery, strings)
    card = [ view.title, view.publisher.presence, view.year, strings.rarity_name(view.rarity) ].compact.join(", ")
    if discovery.nil? then t("grand_inventories.card.missing", card:)
    elsif grand_inventory_mine?(discovery) then t("grand_inventories.card.found_by_you", card:)
    else t("grand_inventories.card.found", card:, player: grand_inventory_pioneer_name(discovery.player))
    end
  end

  def grand_inventory_pioneer_name(player)
    return t("grand_inventories.card.anonymous") if player.nil? || player.removed?

    Accounts::PersonaName.clean(player.persona_name) || t("shell.player.fallback_name")
  end

  def grand_inventory_age(time, now: Time.current)
    minutes = [ ((now - time) / 60).floor, 1 ].max
    if minutes < 60 then t("grand_inventories.age.minutes", count: minutes)
    elsif minutes < 24 * 60 then t("grand_inventories.age.hours", count: minutes / 60)
    else t("grand_inventories.age.days", count: minutes / (24 * 60))
    end
  end
end

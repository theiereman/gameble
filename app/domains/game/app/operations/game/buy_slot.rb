module Game
  # A player buys the next slot of a capacity at the slot price of the settings version they read; the PiCoins are destroyed
  # and the slot is kept for good. A purchase names the slot's number, so a second purchase of the same slot moves nothing.
  # A goal slot makes the aimed set that goal in the same purchase.
  class BuySlot < Operation
    include GoalSteps

    def call(player:, kind:, slot:, settings_token:, aim: nil)
      kind = Capacity::FREE.keys.find { it.to_s == kind.to_s } || raise(ArgumentError, "unknown slot kind: #{kind.inspect}")
      player = step require_player(player)

      transaction do
        step lock_bank(player)
        row = CapacitySlot.lock.find_by(player_id: player.id, kind: kind.to_s)
        limit = Capacity::FREE.fetch(kind) + row&.bought.to_i
        step below_ceiling(kind, limit, slot)
        step next_slot(limit, slot)
        settings = step current_settings(settings_token.to_s)
        price = settings.slot_price(kind, slot)
        step covered(player, price)
        row = keep_slot(player, kind, row)
        goal = step bought_goal(player, aim || {}) if kind == :goal
        Market::Ledger.post(Market::Ledger::Entry.new(player_id: player.id, kind: :slot_purchase, available_delta: -price, settings_id: settings.id))
        step publish(SlotBought.with(player_id: player.id, kind: kind.to_s, goal_id: goal&.id), stream_name: stream_name(player.id))
        goal || row
      end
    rescue ActiveRecord::Deadlocked
      step Failure(:market_busy)
    end

    private

    def below_ceiling(kind, limit, slot)
      ceiling = Capacity::CEILING.fetch(kind)
      limit < ceiling && slot <= ceiling ? Success() : Failure(:slot_ceiling)
    end

    def next_slot(limit, slot) = slot == limit + 1 ? Success() : Failure(:slot_already_bought)

    def current_settings(settings_token)
      settings = Market::CurrentSettings.call
      settings&.token == settings_token ? Success(settings) : Failure(:amounts_changed)
    end

    def covered(player, price) = Market::Balance.call(player).available >= price ? Success() : Failure(:more_than_available)

    def keep_slot(player, kind, row)
      return CapacitySlot.create!(player_id: player.id, kind: kind.to_s, bought: 1) if row.nil?

      row.update!(bought: row.bought + 1)
      row
    end

    def bought_goal(player, aim)
      aim = step goal_aim(player, kind: aim[:kind], key: aim[:key], custom_set: aim[:custom_set])
      return Failure(:goal_already_set) if Goal.exists?(player_id: player.id, **aim.columns)

      goal_inserted(player, aim)
    end
  end
end

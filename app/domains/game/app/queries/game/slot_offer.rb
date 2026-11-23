module Game
  # The next slot a player at a free limit can buy, at the price of the settings version in force: nil under the limit,
  # at the ceiling, or before any settings version.
  module SlotOffer
    Offer = Data.define(:kind, :slot, :price)

    def self.call(kind, limit:, used:)
      return if used < limit || limit >= Capacity::CEILING.fetch(kind)

      settings = Market::CurrentSettings.call
      Offer.new(kind:, slot: limit + 1, price: settings.slot_price(kind, limit + 1)) if settings
    end
  end
end

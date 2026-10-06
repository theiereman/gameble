# The booster screen's island (AD-16, AD-18, AD-23): its props, every word
# resolved here in the current locale.
module BoostersHelper
  # The Booster island's props: where to open (the opening exchange), where
  # to go back and where a revealed card leads (its slug replaces SLUG), the
  # locale's digit delimiter, the published season's number (nil without
  # one), the cards of a regular pack, the bank at the time of the page, the
  # rarity names and icons by tier code name, and every word of
  # `boosters.island` (plural keys as their hash). No database id (AD-15).
  # Times are UTC ISO 8601 with milliseconds, as the exchange answers them.
  def booster_props(bank:, season:)
    {
      openUrl: packs_path,
      hubUrl: home_path,
      cardUrl: card_path(slug: "SLUG"),
      delimiter: t("number.format.delimiter"),
      season: season&.number,
      packSize: Game::Pack::SIZE,
      bank: {
        available: bank[:available],
        reserveFull: bank[:reserve_full],
        nextAvailableAt: bank[:next_available_at] && opening_time(bank[:next_available_at]),
        serverTime: opening_time(Time.current)
      },
      rarityNames: Catalog::Rarity::TIERS.values.to_h { [ it, t("catalog.rarity.#{it}") ] },
      rarityIcons: Catalog::Rarity::TIERS.to_h { |tier, code| [ code, pixel_icon("rarity-#{tier}", class: "booster-card__label-icon").to_str ] },
      strings: booster_strings
    }
  end

  private

  # Every key of `boosters.island`, in lower camel case, nested groups and
  # plural hashes kept as they are.
  def booster_strings
    t("boosters.island").deep_transform_keys { it.to_s.camelize(:lower) }
  end
end

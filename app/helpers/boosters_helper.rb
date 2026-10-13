# The booster screen's island (AD-16, AD-18, AD-23): its props, every word
# resolved here in the current locale.
module BoostersHelper
  # The Booster island's props: where to open (the opening exchange), where
  # to go back, where a revealed card leads and where it is reposted (its
  # slug and season number replace SLUG and NUMBER; no repost without a
  # published season), where the screen's bank is read again in JSON
  # (`bankUrl`), the locale's digit delimiter, the published season's
  # number (nil without one), the cards of a regular pack (the fallback
  # size), the bank at the time of the page (#booster_bank), the rarity
  # names and icons by tier code name, the card zoom's ◀ ▶ icons, every
  # word of `boosters.island` (plural keys as their hash), and `opened`:
  # the opening exchange's answer for an opened pack the island shows dealt
  # and face up (PacksHelper#pack_opening_json), or nil for the canister.
  # No database id. Times are UTC ISO 8601 with milliseconds, as the
  # exchange answers them.
  def booster_props(bank:, season:, next_pack_size:, opened: nil)
    {
      openUrl: packs_path,
      hubUrl: home_path,
      cardUrl: card_path(slug: "SLUG"),
      repostUrl: season && card_repost_path(slug: "SLUG", number: "NUMBER"),
      bankUrl: booster_path(format: :json),
      delimiter: t("number.format.delimiter"),
      season: season&.number,
      packSize: Game::Pack::SIZE,
      bank: booster_bank(bank:, next_pack_size:),
      rarityNames: Catalog::Rarity::TIERS.values.to_h { [ it, t("catalog.rarity.#{it}") ] },
      rarityIcons: Catalog::Rarity::TIERS.to_h { |tier, code| [ code, pixel_icon("rarity-#{tier}", class: "booster-card__label-icon").to_str ] },
      arrowIcons: { previous: zoom_arrow("left"), next: zoom_arrow("right") },
      strings: booster_strings,
      opened:
    }
  end

  # The player's reserve as the island reads it, in the props and in the
  # booster screen's JSON answer: the count, whether the reserve is full,
  # when the next booster arrives, the server's time now, and the size of
  # the pack the next opening opens (Game::NextPackSize: 3 for a daily
  # bonus pack first in line, nil when none is available).
  def booster_bank(bank:, next_pack_size:)
    {
      available: bank[:available],
      reserveFull: bank[:reserve_full],
      nextAvailableAt: bank[:next_available_at] && opening_time(bank[:next_available_at]),
      serverTime: opening_time(Time.current),
      nextPackSize: next_pack_size
    }
  end

  private

  # The card zoom's ◀ or ▶ pixel icon, as HTML.
  def zoom_arrow(direction)
    pixel_icon("arrow-#{direction}", class: "booster-zoom__nav-icon").to_str
  end

  # Every key of `boosters.island`, in lower camel case, nested groups and
  # plural hashes kept as they are.
  def booster_strings
    t("boosters.island").deep_transform_keys { it.to_s.camelize(:lower) }
  end
end

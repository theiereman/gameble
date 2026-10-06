# The opened pack's page (CAP-5) and the booster's opening exchange (AD-23).
module PacksHelper
  # The sizes the opening exchange renders a face at: m in the booster's
  # row on wider screens, xl alone on a phone (story 8.12).
  REVEAL_SIZES = %i[m xl].freeze

  # A card's booster faces, rendered by CardComponent at each REVEAL_SIZES
  # (AD-16): { m: "<span class=\"card …\">…", xl: "…" }.
  def pack_faces(card)
    REVEAL_SIZES.to_h { |size| [ size, render(CardComponent.new(card:, size:, booster: true)).to_str ] }
  end

  # The answer of the opening exchange (AD-23), for a first opening and a
  # replay alike. The pack (by its token), its card back and its cards (by
  # slug, in drawn order, with their display fields and faces) are the pack
  # as it was opened. The bank at `now` (the count, whether the reserve is
  # full, the availability times to come) and the server time are the
  # current ones. The per-tier counts before the opening are recomputed on
  # each answer (the current counts minus the pack's cards), so on a replay
  # they drift if the player gained cards since. `unlockedCardBacks` stays
  # empty until card backs can be unlocked (epic 9). No database id
  # (AD-15). Times are UTC ISO 8601 with milliseconds.
  def pack_opening_json(pack, cards:, player:, now:)
    available = Game::Reserve.count(player.id, now:)
    scheduled = Game::BankSchedule.call(player, now:).map { opening_time(it) }
    {
      pack: { token: pack.token, kind: pack.kind, cardBack: pack.card_back_key, url: pack_path(pack.token) },
      cards: cards.map do |card|
        { slug: card.id, tier: card.rarity, coverUrl: card.image_url, title: card.title, year: card.year,
          label: pack_card_label(card), faces: pack_faces(card) }
      end,
      bank: { available:, reserveFull: Game::Reserve.full?(available), nextAvailableAt: scheduled.first, scheduledAt: scheduled },
      serverTime: opening_time(now),
      tierCountsBefore: Game::TierCounts.before_opening(player, pack).transform_keys { Catalog::Rarity::TIERS.fetch(it) },
      unlockedCardBacks: []
    }
  end

  # The card as the booster speaks it (EXPERIENCE.md, Booster live region):
  # "Hades — Supergiant Games, 2020, Roguelite", the title alone without
  # any detail.
  def pack_card_label(card)
    details = [ card.publisher.presence, card.year, card.genre && SetLabel.genre(card.genre) ].compact.join(", ")
    details.empty? ? card.title : t("boosters.island.card_label", title: card.title, details:)
  end

  # A time as the exchange and the booster's props carry it.
  def opening_time(time)
    time.utc.iso8601(3)
  end
end

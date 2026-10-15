# The opened pack's page (CAP-5) and the booster's opening exchange (AD-23).
module PacksHelper
  # The sizes the opening exchange renders a face at: s in the booster's
  # row from 720 to 899px, m from 900px, xl alone on a phone (under 720px).
  REVEAL_SIZES = %i[s m xl].freeze

  # A card's booster faces, rendered by CardComponent at each REVEAL_SIZES
  # (AD-16): { m: "<span class=\"card …\">…", xl: "…" }.
  def pack_faces(card)
    REVEAL_SIZES.to_h { |size| [ size, render(CardComponent.new(card:, size:, booster: true)).to_str ] }
  end

  # The answer of the opening exchange, for a first opening and a
  # replay alike. The pack (by its token), its card back and its cards (by
  # slug, in drawn order, with their display fields and faces) are the pack
  # as it was opened. The bank at `now` (the count, whether the reserve is
  # full, the availability times to come, the card count of the pack the
  # next opening opens, nil when none is available) and the server time
  # are the current ones. The per-tier counts before the opening are recomputed on
  # each answer (the current counts minus the pack's cards), so on a replay
  # they drift if the player gained cards since. `setTiers` are the set
  # tiers the opening reached, the same on a replay. `unlockedCardBacks` stays
  # empty until card backs can be unlocked. No database id. Times are UTC
  # ISO 8601 with milliseconds.
  def pack_opening_json(pack, cards:, player:, now:)
    available = Game::Reserve.count(player.id, now:)
    scheduled = Game::BankSchedule.call(player, now:).map { opening_time(it) }
    {
      pack: { token: pack.token, kind: pack.kind, cardBack: pack.card_back_key, url: pack_path(pack.token) },
      cards: cards.map do |card|
        { slug: card.id, season: card.season_number, tier: card.rarity, coverUrl: card.image_url, title: card.title, year: card.year,
          label: pack_card_label(card), faces: pack_faces(card) }
      end,
      bank: { available:, reserveFull: Game::Reserve.full?(available), nextAvailableAt: scheduled.first, scheduledAt: scheduled,
              nextPackSize: Game::NextPackSize.call(player, now:) },
      serverTime: opening_time(now),
      tierCountsBefore: Game::TierCounts.before_opening(player, pack).transform_keys { Catalog::Rarity::TIERS.fetch(it) },
      setTiers: pack_set_tiers(pack),
      unlockedCardBacks: []
    }
  end

  # The set tiers the opening reached, read back by its pack: a replay
  # answers the same ones.
  def pack_set_tiers(pack)
    Game::PackSetTiers.call(pack).map do |row|
      { kind: row.kind, key: row.key, name: SetLabel.for(row), tier: row.tier, required: row.required, total: row.total }
    end
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

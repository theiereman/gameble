# The opened pack's page (CAP-5, story 3.6) and the booster's opening
# exchange (AD-23).
module PacksHelper
  # The sizes the reveal shows a face at: m beside the others on wider
  # screens, xl alone on a phone.
  REVEAL_SIZES = %i[m xl].freeze

  # The PackReveal island's props: the cards in their drawn order, each with
  # its faces rendered here by CardComponent (the island draws only the
  # backs and the turn), and every word resolved here (AD-16).
  def pack_reveal_props(cards, next_pack:)
    {
      cards: cards.map { |card| { rarity: card.rarity, title: card.title, faces: pack_faces(card) } },
      cardStrings: CardStrings.new.to_props,
      strings: {
        cards: t("packs.show.cards"), flipAll: t("packs.show.flip_all"), next: t("packs.show.next"), previous: t("packs.show.previous"),
        allFlipped: t("packs.show.all_flipped"),
        progress: (1..cards.size).map { |position| t("packs.show.progress", position:, count: cards.size) },
        openNextPack: t("packs.show.open_next_pack"), backToHub: t("packs.show.back_to_hub"),
        failed: t("packs.show.failed"), reload: t("packs.show.reload")
      },
      openPackUrl: (packs_path if next_pack),
      hubUrl: home_path
    }
  end

  # A card's booster faces, rendered by CardComponent at each REVEAL_SIZES
  # (AD-16): { m: "<span class=\"card …\">…", xl: "…" }.
  def pack_faces(card)
    REVEAL_SIZES.to_h { |size| [ size, render(CardComponent.new(card:, size:, booster: true)).to_str ] }
  end

  # The answer of the opening exchange (AD-23), for a first opening and a
  # replay alike. The pack (by its token), its card back and its cards (by
  # slug, in drawn order, with their faces) are the pack as it was opened.
  # The bank at `now` (the count, whether the reserve is full, the
  # availability times to come) and the server time are the current ones.
  # The per-tier counts before the opening are recomputed on each answer
  # (the current counts minus the pack's cards), so on a replay they drift
  # if the player gained cards since. `unlockedCardBacks` stays empty until
  # card backs can be unlocked (epic 9). No database id (AD-15). Times are
  # UTC ISO 8601 with milliseconds.
  def pack_opening_json(pack, cards:, player:, now:)
    available = Game::Reserve.count(player.id, now:)
    scheduled = Game::BankSchedule.call(player, now:).map { opening_time(it) }
    {
      pack: { token: pack.token, kind: pack.kind, cardBack: pack.card_back_key, url: pack_path(pack.token) },
      cards: cards.map { |card| { slug: card.id, tier: card.rarity, coverUrl: card.image_url, faces: pack_faces(card) } },
      bank: { available:, reserveFull: Game::Reserve.full?(available), nextAvailableAt: scheduled.first, scheduledAt: scheduled },
      serverTime: opening_time(now),
      tierCountsBefore: Game::TierCounts.before_opening(player, pack).transform_keys { Catalog::Rarity::TIERS.fetch(it) },
      unlockedCardBacks: []
    }
  end

  private

  def opening_time(time)
    time.utc.iso8601(3)
  end
end

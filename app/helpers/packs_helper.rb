# The opened pack's page (CAP-5, story 3.6).
module PacksHelper
  # The sizes the reveal shows a face at: m beside the others on wider
  # screens, xl alone on a phone.
  REVEAL_SIZES = %i[m xl].freeze

  # The PackReveal island's props: the cards in their drawn order, each with
  # its faces rendered here by CardComponent (the island draws only the
  # backs and the turn), and every word resolved here (AD-16).
  def pack_reveal_props(cards, next_pack:)
    {
      cards: cards.map do |card|
        { rarity: card.rarity, title: card.title,
          faces: REVEAL_SIZES.to_h { |size| [ size, render(CardComponent.new(card:, size:, booster: true)).to_str ] } }
      end,
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
end

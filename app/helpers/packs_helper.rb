module PacksHelper
  REVEAL_SIZES = %i[s m xl].freeze
  BACK_SIZES = %i[s m xl].freeze

  def pack_faces(card, goals: [])
    REVEAL_SIZES.to_h { |size| [ size, render(CardComponent.new(card:, size:, booster: true, goals: goals.map(&:position))).to_str ] }
  end

  def pack_card_back(pack)
    card_back_json(pack.card_back_key, pack.card_back_season)
  end

  def card_back_json(key, season)
    back = Game::CardBacks.find(key) || Game::CardBacks.find(Game::CardBacks::STANDARD)
    { key: back.key, season:, urls: BACK_SIZES.to_h { |size| [ size, vite_asset_path("images/pixel/#{back.asset}-#{size}.png") ] } }
  end

  def pack_head_json(pack, card_back:)
    { token: pack.token, kind: pack.kind, cardBack: card_back, url: pack_path(pack.token), revealUrl: pack_reveal_path(pack.token) }
  end

  def pack_card_back_data(pack)
    back = pack_card_back(pack)
    back[:urls].transform_keys { :"card_back_#{it}" }.merge(card_back: back[:key], card_back_season: back[:season])
  end

  def pack_opening_json(pack, cards:, player:, now:, goals_reached: [], goals: GoalMarks::NONE)
    counts = Game::Reserve.counts(player.id, now:)
    scheduled = Game::BankSchedule.call(player, now:).map { opening_time(it) }
    sizes = Game::NextPackSize.call(player, now:)
    {
      pack: pack_head_json(pack, card_back: pack_card_back(pack)),
      cards: pack_cards_json(cards, Game::FirstCopies.call(player, pack), goals:),
      bank: { available: counts.standard, special: counts.special, openable: counts.openable, reserveFull: Game::Reserve.full?(counts.standard),
              nextAvailableAt: scheduled.first, scheduledAt: scheduled, nextPackSize: sizes["standard"],
              nextSpecialSize: sizes["special"], nextSpecialKind: counts.next_special_kind },
      serverTime: opening_time(now),
      tierCountsBefore: tier_counts_json(Game::TierCounts.before_opening(player, pack)),
      setTiers: pack_set_tiers(pack),
      goalsReached: goals_reached,
      next: held_pack_after_json(pack, player:, now:)
    }
  end

  def pack_cards_json(cards, first_copies, goals:)
    cards.zip(first_copies).map { |card, first_copy| pack_card_json(card, goals.goals_for(card.card_id), first_copy:) }
  end

  def tier_counts_json(counts)
    counts.transform_keys { Catalog::Rarity::TIERS.fetch(it) }
  end

  def pack_card_json(card, goals, first_copy: false)
    pack_card_fields(card, goals:, first_copy:).merge(faces: pack_faces(card, goals:))
  end

  def pack_card_fields(card, goals: [], first_copy: false)
    { slug: card.id, season: card.season_number, tier: card.rarity, coverUrl: card.image_url, title: card.title, year: card.year,
      label: pack_card_label(card), goals: goal_card_words(goals), firstCopy: first_copy }
  end

  def pack_set_tiers(pack)
    Game::PackSetTiers.call(pack).map do |row|
      { kind: row.kind, key: row.key, name: SetLabel.for(row), tier: row.tier, required: row.required, held: row.held, total: row.total,
        thresholds: row.thresholds.map { |tier, required| { tier:, required: } },
        url: library_set_path(kind: row.kind, key: row.key) }
    end
  end

  def pack_card_label(card)
    details = [ card.publisher.presence, card.year, card.genre && SetLabel.genre(card.genre) ].compact.join(", ")
    details.empty? ? card.title : t("booster.card_label", title: card.title, details:)
  end

  def opening_time(time)
    time.utc.iso8601(3)
  end
end

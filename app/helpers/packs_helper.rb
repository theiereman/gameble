module PacksHelper
  REVEAL_SIZES = %i[s m xl].freeze
  BACK_SIZES = %i[s m xl].freeze

  def pack_faces(card)
    REVEAL_SIZES.to_h { |size| [ size, render(CardComponent.new(card:, size:, booster: true)).to_str ] }
  end

  def pack_card_back(pack)
    back = Game::CardBacks.find(pack.card_back_key) || Game::CardBacks.find(Game::CardBacks::STANDARD)
    { key: back.key, season: pack.card_back_season, urls: BACK_SIZES.to_h { |size| [ size, vite_asset_path("images/pixel/#{back.asset}-#{size}.png") ] } }
  end

  def pack_card_back_data(pack)
    back = pack_card_back(pack)
    back[:urls].transform_keys { :"card_back_#{it}" }.merge(card_back: back[:key], card_back_season: back[:season])
  end

  def pack_opening_json(pack, cards:, player:, now:)
    counts = Game::Reserve.counts(player.id, now:)
    scheduled = Game::BankSchedule.call(player, now:).map { opening_time(it) }
    {
      pack: { token: pack.token, kind: pack.kind, cardBack: pack_card_back(pack), url: pack_path(pack.token) },
      cards: cards.map { pack_card_fields(it).merge(faces: pack_faces(it)) },
      bank: { available: counts.standard, special: counts.special, openable: counts.openable, reserveFull: Game::Reserve.full?(counts.standard),
              nextAvailableAt: scheduled.first, scheduledAt: scheduled, nextPackSize: Game::NextPackSize.call(player, now:),
              nextSpecialKind: counts.next_special_kind },
      serverTime: opening_time(now),
      tierCountsBefore: Game::TierCounts.before_opening(player, pack).transform_keys { Catalog::Rarity::TIERS.fetch(it) },
      setTiers: pack_set_tiers(pack),
      unlockedCardBacks: []
    }
  end

  def pack_card_fields(card)
    { slug: card.id, season: card.season_number, tier: card.rarity, coverUrl: card.image_url, title: card.title, year: card.year,
      label: pack_card_label(card) }
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

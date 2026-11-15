module Game
  module DeckSteps
    Placed = Data.define(:slot, :count)

    private

    def clean_deck_name(name)
      name = VisibleName.call(name)
      if name.empty?
        Failure(:deck_name_required)
      elsif name.length > Deck::NAME_LIMIT
        Failure(:deck_name_too_long)
      else
        Success(name)
      end
    end

    def deck_name_free(player, name, except: nil)
      taken = Deck.where(player_id: player.id).named(name)
      taken = taken.where.not(id: except.id) if except
      taken.exists? ? Failure(:deck_name_taken) : Success()
    end

    def locked_deck(player, token)
      deck = Deck.where(player_id: player.id).lock.find_by(token:) if token.is_a?(String)
      deck ? Success(deck) : Failure(:deck_not_found)
    end

    def locked_cards(deck)
      DeckCard.where(deck_id: deck.id).order(:id).lock.to_a
    end

    def decked_elsewhere(player, deck, card_season_ids)
      DeckCard.where(deck_id: Deck.where(player_id: player.id).where.not(id: deck.id).select(:id), card_season_id: card_season_ids)
        .order(:id).lock.pluck(:card_season_id).to_set
    end

    def lock_holdings(player, card_season_ids)
      TradeLocks.holdings(player.id, card_season_ids)
    end

    def reserve_copy(player, card_season_id)
      shift_reserved(player, [ card_season_id ], +1)
    end

    def release_copies(player, card_season_ids)
      shift_reserved(player, card_season_ids, -1) if card_season_ids.any?
    end

    def shift_reserved(player, card_season_ids, by)
      Holding.where(player_id: player.id, card_season_id: card_season_ids)
        .update_all([ "reserved = reserved + ?, updated_at = ?", by, Time.current ])
    end

    def deck_published(event, player, deck, **data)
      publish(event.new(data: { player_id: player.id, deck_id: deck.id, **data }), stream_name: stream_name(player.id))
    end
  end
end

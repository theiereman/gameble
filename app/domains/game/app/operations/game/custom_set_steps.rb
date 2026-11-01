module Game
  module CustomSetSteps
    private

    def clean_name(name)
      name = name.is_a?(String) ? visible(name) : ""
      if name.empty?
        Failure(:name_required)
      elsif name.length > CustomSet::NAME_LIMIT
        Failure(:name_too_long)
      else
        Success(name)
      end
    end

    def games_in_range(card_ids)
      card_ids = Array(card_ids).uniq
      if card_ids.size < CustomSet::GAMES.min
        Failure(:too_few_games)
      elsif card_ids.size > CustomSet::GAMES.max
        Failure(:too_many_games)
      else
        Success(card_ids)
      end
    end

    def in_catalog(card_ids)
      Catalog::PublishedCardIds.within(card_ids).size == card_ids.size ? Success() : Failure(:game_not_in_catalog)
    end

    def insert_games(custom_set, card_ids)
      CustomSetGame.insert_all!(card_ids.map { |card_id| { custom_set_id: custom_set.id, card_id: } })
    end

    def visible(name)
      name = name.dup.force_encoding(Encoding::UTF_8).scrub("").unicode_normalize(:nfc)
      name = name.gsub(Accounts::PersonaName::INVISIBLE, "").gsub(Accounts::PersonaName::SPACE, " ").squish
      Accounts::PersonaName::VISIBLE.match?(name) ? name : ""
    end

    def name_free(player, name, except: nil)
      taken = CustomSet.custom.where(player_id: player.id).named(name)
      taken = taken.where.not(id: except.id) if except
      taken.exists? ? Failure(:name_taken) : Success()
    end

    def locked_custom_set(player, token)
      custom_set = CustomSet.custom.where(player_id: player.id).lock.find_by(token: token.to_s) if token.is_a?(String)
      custom_set ? Success(custom_set) : Failure(:custom_set_not_found)
    end

    def locked_library_set(player, token)
      CustomSet.steam_library.where(player_id: player.id).lock.find_by(token:) if token.is_a?(String)
    end

    def published(event, player, custom_set)
      publish(event.new(data: { player_id: player.id, custom_set_id: custom_set.id }), stream_name: stream_name(player.id))
    end
  end
end

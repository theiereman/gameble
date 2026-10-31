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

    def published(event, player, custom_set)
      publish(event.new(data: { player_id: player.id, custom_set_id: custom_set.id }), stream_name: stream_name(player.id))
    end
  end
end

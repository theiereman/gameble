module Game
  module GoalSteps
    Aim = Data.define(:columns, :complete)

    private

    def goal_aim(player, kind:, key:, custom_set:)
      custom_set.nil? ? game_set_aim(player, kind, key) : custom_set_aim(player, custom_set)
    end

    def custom_set_aim(player, token)
      custom_set = own_custom_set(player, token)
      return Failure(:custom_set_not_found) unless custom_set&.custom?

      standing = CustomSetStandings.call(player, tokens: [ token ]).sole
      Success(Aim.new(columns: { custom_set_id: custom_set.id }, complete: standing.complete?))
    end

    def game_set_aim(player, kind, key)
      season = Catalog::PublishedSeason.call if Catalog::SetKind::ALL.include?(kind) && key.is_a?(String)
      album = Catalog::SetAlbum.call(season:, kind:, key:) if season
      return Failure(:goal_set_not_found) if album.nil?

      card_ids = album.members.map(&:last)
      held = HeldGames.call(player.id, card_ids:)
      Success(Aim.new(columns: { set_kind: kind, set_key: key }, complete: card_ids.any? && card_ids.all? { held.key?(it) }))
    end

    def goal_columns(player, kind:, key:, custom_set:)
      if !custom_set.nil?
        custom_set_id = own_custom_set(player, custom_set)&.id
        { custom_set_id: } if custom_set_id
      elsif kind.is_a?(String) && key.is_a?(String)
        { set_kind: kind, set_key: key }
      end
    end

    def own_custom_set(player, token)
      CustomSet.find_by(player_id: player.id, token:) if token.is_a?(String)
    end

    def goal_published(event, player, goal)
      publish(event.new(data: { player_id: player.id, goal_id: goal.id }), stream_name: stream_name(player.id))
    end
  end
end

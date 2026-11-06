module Game
  class ChooseAvatar < Operation
    def call(player:, avatar:)
      player = step require_player(player)
      avatar = step known(player, avatar)

      transaction do
        step lock_bank(player)
        step unlocked(player, avatar)
        store(player, avatar)
        step publish(AvatarChosen.new(data: { player_id: player.id, avatar: avatar.key }), stream_name: stream_name(player.id))
        avatar
      end
    end

    private

    def known(player, key)
      avatar = Avatars.find(key)
      avatar&.available_to?(player) ? Success(avatar) : Failure(:unknown_avatar)
    end

    def unlocked(player, avatar)
      earned = avatar.achievement ? AchievementUnlock.where(player_id: player.id, achievement: avatar.achievement).pluck(:achievement) : []
      avatar.open_to?(player, earned) ? Success() : Failure(:avatar_locked)
    end

    def store(player, avatar)
      PlayerState.insert({ player_id: player.id }, unique_by: :player_id)
      PlayerState.where(player_id: player.id).update_all(active_avatar: (avatar.key unless avatar.default?), updated_at: Time.current)
    end
  end
end

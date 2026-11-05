module Game
  class ChooseAvatar < Operation
    def call(player:, avatar:)
      player = step require_player(player)
      avatar = step known(avatar)

      transaction do
        step lock_bank(player)
        step unlocked(player, avatar)
        store(player, avatar)
        step publish(AvatarChosen.new(data: { player_id: player.id, avatar: avatar.key }), stream_name: stream_name(player.id))
        avatar
      end
    end

    private

    def known(key)
      avatar = Avatars.find(key)
      avatar ? Success(avatar) : Failure(:unknown_avatar)
    end

    def unlocked(player, avatar)
      return Success() if avatar.free?

      AchievementUnlock.exists?(player_id: player.id, achievement: avatar.achievement) ? Success() : Failure(:avatar_locked)
    end

    def store(player, avatar)
      PlayerState.insert({ player_id: player.id }, unique_by: :player_id)
      PlayerState.where(player_id: player.id).update_all(active_avatar: (avatar.key unless avatar.default?), updated_at: Time.current)
    end
  end
end

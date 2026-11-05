module Game
  module AvatarShelf
    Row = Data.define(:avatar, :unlocked, :active) do
      def key = avatar.key

      def locked? = !unlocked
    end

    def self.call(player)
      earned = AchievementUnlock.where(player_id: player.id).pluck(:achievement).to_set
      active = ActiveAvatar.call(player)
      Avatars::CATALOGUE.map do |avatar|
        Row.new(avatar:, unlocked: avatar.free? || earned.include?(avatar.achievement), active: avatar == active)
      end
    end
  end
end

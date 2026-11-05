module AvatarsHelper
  def player_avatar(player, class_name:)
    pixel_icon(avatar_of(player).icon, class: class_name)
  end

  def preload_avatars(players)
    missing = players.compact.reject { known_avatars.key?(it.id) }
    known_avatars.merge!(Game::ActiveAvatar.for_players(missing)) unless missing.empty?
  end

  private
    def avatar_of(player)
      return Game::Avatars.default if player.nil?

      preload_avatars([ player ])
      known_avatars.fetch(player.id)
    end

    def known_avatars
      @known_avatars ||= {}
    end
end

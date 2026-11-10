module Game
  module Market
    class SettingsChanged < RubyEventStore::Event
      STREAM = "Game::Market$settings"

      def self.about(settings) = new(data: { settings_id: settings.id })
    end
  end
end

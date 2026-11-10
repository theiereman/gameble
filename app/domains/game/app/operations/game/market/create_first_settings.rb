module Game
  module Market
    # Run at every deploy: the first version, closed, once.
    class CreateFirstSettings < ApplicationOperation
      LOCK_KEY = 0x4D4B5453

      def call
        transaction do
          Settings.connection.execute(Settings.sanitize_sql_array([ "SELECT pg_advisory_xact_lock(?)", LOCK_KEY ]))
          existing = Settings.order(:id).first
          next existing if existing

          settings = Settings.create!(StartingSettings::ATTRIBUTES)
          step publish(SettingsChanged.new(data: { settings_id: settings.id }), stream_name: "Game::Market$settings")
          settings
        end
      end
    end
  end
end

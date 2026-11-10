module Game
  module Market
    # An administrator changes the economy values: a whole candidate row, checked against the version the form drew, becomes the next version.
    class ChangeSettings < Operation
      include AnnouncesChange

      def call(player:, settings_token:, candidate:, message_fr:, message_en:)
        step require_administrator(player)
        changes = candidate.to_h.symbolize_keys.slice(*SettingsRules::EDITABLE)

        transaction do
          current = step current_version(settings_token)
          step within_rules(current, changes)
          settings = current.successor(author: player, **changes)
          settings.save!
          announce(player, message_fr, message_en)
          step publish(SettingsChanged.new(data: { settings_id: settings.id }), stream_name: "Game::Market$settings")
          settings
        end
      rescue ActiveRecord::RecordNotUnique
        step Failure(:settings_changed)
      rescue ActiveRecord::Deadlocked
        step Failure(:market_busy)
      end

      private

      def require_administrator(player)
        Accounts::Player.acting_staff?(player) && player.administrator? ? Success(player) : Failure(:administrator_required)
      end

      def current_version(settings_token)
        current = CurrentSettings.call
        current && settings_token.present? && current.token == settings_token ? Success(current) : Failure(:settings_changed)
      end

      def within_rules(current, changes) = SettingsRules.new(current).violations(changes).empty? ? Success() : Failure(:invalid_settings)
    end
  end
end

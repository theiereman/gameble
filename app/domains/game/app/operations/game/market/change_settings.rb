module Game
  module Market
    # An administrator changes the economy values, or closes the market: a whole candidate row, checked against the version the form drew, becomes the next version.
    class ChangeSettings < Operation
      include AnnouncesChange
      include RequiresAdministrator

      def call(player:, settings_token:, candidate: {}, message_fr:, message_en:, close: false)
        step require_administrator(player)
        changes = candidate.to_h.symbolize_keys.slice(*SettingsRules::EDITABLE)

        transaction do
          current = step current_version(settings_token)
          settings = step successor(current, player, changes, close)
          settings.save!
          announce(player, message_fr, message_en)
          step publish(SettingsChanged.about(settings), stream_name: SettingsChanged::STREAM)
          settings
        end
      rescue ActiveRecord::RecordNotUnique
        step Failure(:settings_changed)
      rescue ActiveRecord::Deadlocked
        step Failure(:market_busy)
      end

      private

      def current_version(settings_token)
        current = CurrentSettings.call
        current && settings_token.present? && current.token == settings_token ? Success(current) : Failure(:settings_changed)
      end

      def successor(current, player, changes, close)
        return Failure(:market_already_closed) if close && !current.open
        return Success(current.successor(author: player, open: false)) if close

        within_rules(current, changes).fmap { current.successor(author: player, **changes) }
      end

      def within_rules(current, changes) = SettingsRules.new(current).violations(changes).empty? ? Success() : Failure(:invalid_settings)
    end
  end
end

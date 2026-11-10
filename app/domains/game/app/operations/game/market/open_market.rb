module Game
  module Market
    # An administrator opens the market, or reopens it, recording both legal confirmations and announcing it to the players.
    class OpenMarket < Operation
      include AnnouncesChange

      def call(player:, terms_confirmed:, odds_confirmed:, message_fr:, message_en:)
        step require_administrator(player)
        step confirmed(terms_confirmed, :terms_not_confirmed)
        step confirmed(odds_confirmed, :odds_not_confirmed)

        transaction do
          current = CurrentSettings.call
          step closed(current)
          settings = opened_version(current, player)
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

      def confirmed(value, code) = value == true ? Success() : Failure(code)

      def closed(current) = current&.open ? Failure(:market_already_open) : Success()

      def opened_version(current, player)
        now = Time.current
        (current || Settings.new(StartingSettings::ATTRIBUTES)).successor(
          author: player, open: true, terms_confirmed_at: now, odds_confirmed_at: now, first_opened_at: current&.first_opened_at || now
        )
      end
    end
  end
end

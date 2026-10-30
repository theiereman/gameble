module PushNotices
  EVENTS = [ Game::TradeProposed, Game::TradeCountered, Game::TradeAccepted, Game::InvitationSent ].freeze

  REQUIRED_SETTINGS = { "apple" => %i[key_id encryption_key team_id], "google" => %i[encryption_key project_id] }.freeze

  BATCHES = :push_notice_batches
  BATCH = AfterCommitBatch.new(BATCHES) { |notices| PushNoticeJob.perform_later(notices) }

  class << self
    def call(event)
      BATCH.add(notices(event))
    end

    def notices(event)
      data = event.data
      case event
      when Game::TradeProposed
        [ { player_id: data[:recipient_id], actor_id: data[:proposer_id], kind: "trade_proposed" } ]
      when Game::TradeCountered
        [ { player_id: data[:recipient_id], actor_id: data[:proposer_id], kind: "trade_countered" } ]
      when Game::TradeAccepted
        [ { player_id: data[:proposer_id], actor_id: data[:recipient_id], kind: "trade_accepted" } ]
      when Game::InvitationSent
        [ { player_id: data[:recipient_id], actor_id: data[:sender_id], kind: "invitation_sent" } ]
      else
        []
      end
    end

    def notification(kind, actor_name:, locale:)
      I18n.with_locale(locale) do
        ApplicationPushNotification.with_data(path: path(kind, locale)).new(
          title: I18n.t("push_notices.#{kind}.title"),
          body: I18n.t("push_notices.#{kind}.body", name: actor_name),
          thread_id: kind.start_with?("trade") ? "trades" : "friends"
        )
      end
    end

    def deliverable?(device)
      settings = ActionPushNative.config[device.platform.to_sym] || {}
      REQUIRED_SETTINGS.fetch(device.platform).all? { settings[it].present? }
    end

    private

    def path(kind, locale)
      helpers = Rails.application.routes.url_helpers
      kind == "invitation_sent" ? helpers.friends_path(locale:) : helpers.trades_path(locale:)
    end
  end
end

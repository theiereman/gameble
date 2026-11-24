module MarketPushNotice
  EVENTS = [ Game::Market::BidPlaced, Game::Market::AuctionSold, Game::Market::AuctionUnsold, Game::Market::ListingWithdrawn,
    Game::Market::LeadVoided, Game::Market::OrderServed, Game::Market::OrderExpired, Game::Market::WantedChoicesApplied, Game::Market::CardListed ].freeze

  KINDS = %w[outbid won sold unsold lead_voided withdrawn].freeze
  ORDER_KINDS = %w[order_served order_expired order_leads order_beaten].freeze
  SALES_KINDS = %w[sold unsold lead_voided].freeze

  BATCHES = :market_push_notice_batches
  BATCH = AfterCommitBatch.new(BATCHES) { |notices| MarketPushNoticeJob.perform_later(notices) }

  class << self
    def call(event)
      BATCH.add(notices(event))
    end

    def notices(event)
      data = event.data
      case event
      when Game::Market::OrderServed then [ { player_id: data[:buyer_id], order_id: data[:order_id] } ]
      when Game::Market::OrderExpired then [ { player_id: data[:player_id], order_id: data[:order_id] } ]
      when Game::Market::WantedChoicesApplied then data[:sales].map { { player_id: it[:buyer_id], order_id: it[:order_id] } } + converted_notices(data)
      when Game::Market::CardListed then converted_notices(data)
      else listing_players(event, data).compact.map { { player_id: it, listing_id: data[:listing_id] } }
      end
    end

    def notification(line, locale:)
      I18n.with_locale(locale) do
        ApplicationPushNotification.with_data(path: path(line, locale)).new(
          title: I18n.t("push_notices.market_#{line.kind}.title"),
          body: I18n.t("push_notices.market_#{line.kind}.body", card: line.card, name: name(line.other), amount: amount(line.amount)),
          thread_id: "market"
        )
      end
    end

    private

    def converted_notices(data) = data.fetch(:converted, []).map { { player_id: it[:owner_id], order_id: it[:order_id] } }

    def listing_players(event, data)
      case event
      when Game::Market::BidPlaced then data[:outbid_player_id] == data[:bidder_id] ? [] : [ data[:outbid_player_id] ]
      when Game::Market::AuctionSold then data.values_at(:winner_id, :seller_id)
      when Game::Market::AuctionUnsold, Game::Market::LeadVoided then [ data[:seller_id] ]
      when Game::Market::ListingWithdrawn then [ data[:leader_id] ]
      end
    end

    def path(line, locale)
      helpers = Rails.application.routes.url_helpers
      case line.kind.to_s
      when "order_served" then helpers.card_season_path(locale:, slug: line.edition.id, number: line.edition.season_number)
      when "order_expired" then helpers.market_my_orders_path(locale:)
      when "order_leads", "order_beaten" then helpers.market_listing_path(locale:, token: line.listing_token)
      when *SALES_KINDS then helpers.market_my_sales_path(locale:)
      else helpers.market_listing_path(locale:, token: line.token)
      end
    end

    def name(player) = player && Accounts::PersonaName.clean(player.persona_name) || I18n.t("shell.player.fallback_name")

    def amount(picoins) = ApplicationController.helpers.picoins_label(picoins.to_i)
  end
end

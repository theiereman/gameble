module Market
  class EntrustmentsController < ApplicationController
    include PublicRead

    throttle_player to: 10, only: :create, path: -> { new_market_entrustment_path }, alert: "market.entrustments.create.throttled"

    def new
      authorize %i[market entrustment], :new?
      load_page
    end

    def create
      authorize %i[market entrustment], :create?
      ids = Game::Market::EntrustableCopies.resolve(ticked.keys)
      lines = ticked.filter_map { |ref, copies| [ ids[ref], copies ] if ids.key?(ref) }
      result = Game::Market::EntrustCards.new.call(player: current_player, lines:, settings_token: params[:settings].to_s)
      if result.success?
        @entrusted = result.value!
      else
        flash.now[:alert] = Game::Market::EntrustCards.failure_message(result.failure)
        load_page
        render :new, status: :unprocessable_content
      end
    end

    private
      def load_page
        @settings = Game::Market::CurrentSettings.call
        @open = @settings&.open.present?
        @copies = current_player && @settings ? Game::Market::EntrustableCopies.call(current_player, settings: @settings) : []
        @ticked = ticked
      end

      def ticked
        copies = params[:copies]
        copies.respond_to?(:to_unsafe_h) ? copies.to_unsafe_h.select { |ref, count| ref.is_a?(String) && count.is_a?(String) } : {}
      end
  end
end

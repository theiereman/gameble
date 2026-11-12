module Market
  class BidsController < ApplicationController
    include BidRefusals

    rate_limit to: 20, within: 1.minute, only: :create, by: -> { current_player&.id || request.remote_ip },
      with: -> { answer_refusal(:throttled, status: :too_many_requests) }

    def create
      authorize %i[market bid], :create?
      listing_id = Game::Market::ListingIdByToken.call(token) || raise(ActiveRecord::RecordNotFound)
      result = Game::Market::PlaceBid.new.call(player: current_player, listing_id:, maximum: params[:maximum].to_s)
      result.success? ? answer_success(result.value!) : answer_failure(result.failure)
    end

    private
      def answer_success(answer)
        answer_with(region(answer:, focus: answer.branch == :beaten ? "field" : "heading"), status: :ok)
      end

      def answer_failure(code)
        return refuse if code == :player_required

        answer_refusal(code, status: :unprocessable_content)
      end
  end
end

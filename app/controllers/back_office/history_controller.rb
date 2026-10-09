module BackOffice
  class HistoryController < BaseController
    include Pagy::Method

    PAGE_SIZE = 50
    MAX_PAGE = 100_000

    def index
      authorize [ :back_office, :history ], :index?
      @filtered = params[:player].present?
      @player = filtered_player if @filtered
      return if @filtered && @player.nil?

      @pagy, @actions = pagy(:offset, Accounts::ModerationHistory.call(@player), limit: PAGE_SIZE,
        page: params[:page].to_s.to_i.clamp(1, MAX_PAGE))
    end

    private
      def filtered_player
        player = Accounts::PlayerByToken.call(params[:player])
        player unless player.nil? || player.deleted?
      end
  end
end

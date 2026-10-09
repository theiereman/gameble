module BackOffice
  class PlayersController < BaseController
    include Pagy::Method

    PAGE_SIZE = 50
    MAX_PAGE = 100_000

    def index
      authorize [ :back_office, :players ], :index?
      @query = Accounts::PlayerSearch.normalize(params[:q])
      @pagy, @players = pagy(:offset, Accounts::PlayerSearch.call(@query), limit: PAGE_SIZE, page: params[:page].to_s.to_i.clamp(1, MAX_PAGE))
    end
  end
end

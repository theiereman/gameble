module Market
  # A grid of a player's free copies served one page at a time, narrowed by the filter in the query.
  module CopyGrid
    extend ActiveSupport::Concern

    include Pagy::Method

    GRID_SIZE = CollectionGridLoading::GRID_SIZE

    private
      def copy_filter(doubles_by_default:)
        asked = params[:filter]
        return Game::Market::CopyFilter.new(doubles: doubles_by_default) unless asked.respond_to?(:to_unsafe_h)

        Game::Market::CopyFilter.new(query: asked[:query].is_a?(String) ? asked[:query] : "", rarities: Array(asked[:rarities]).grep(String),
          doubles: asked[:doubles].present?)
      end

      # The page links carry the filter alone, whatever else a post sent.
      def copy_pages(count, path:, filter:)
        page = params[:page].to_s.to_i.clamp(1, CollectionGridLoading::MAX_PAGE)
        query = { "filter" => filter.to_params.deep_stringify_keys }
        pagy(:offset, [], count:, limit: GRID_SIZE, page:, request: { base_url: request.base_url, path:, params: query }).first
      end
  end
end

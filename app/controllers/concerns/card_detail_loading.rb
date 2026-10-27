module CardDetailLoading
  extend ActiveSupport::Concern

  private
    def load_card_detail
      @detail = Catalog::CardDetail.call(slug: params[:slug], locale: I18n.locale, season_number: season_number_from_path)
      raise ActiveRecord::RecordNotFound if @detail.nil?
    end

    def season_number_from_path
      request.path_parameters[:number]&.to_i
    end
end

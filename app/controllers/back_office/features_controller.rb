module BackOffice
  class FeaturesController < BaseController
    rate_limit to: 30, within: 1.minute, only: :update

    def index
      authorize [ :back_office, :features ], :index?
      @enabled = Game::EnabledFeatures.call
    end

    def update
      authorize [ :back_office, :features ], :update?

      enabled = params[:enabled] == "1"
      result = Game::SetFeatureFlag.new.call(player: current_player, key: params[:key], enabled:)
      if result.success?
        name = t("back_office.features.index.names.#{params[:key]}")
        redirect_to back_office_features_path, notice: t(enabled ? ".turned_on" : ".turned_off", name:), status: :see_other
      else
        redirect_refused Game::SetFeatureFlag, result, back_office_features_path
      end
    end
  end
end

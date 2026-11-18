module FeatureGate
  extend ActiveSupport::Concern

  class_methods do
    # A switched-off feature answers "not found", as if its pages did not exist.
    def require_feature(key, **filters)
      before_action(**filters) do
        raise ActionController::RoutingError, "No route matches #{request.path.inspect}" unless helpers.feature_enabled?(key)
      end
    end
  end
end

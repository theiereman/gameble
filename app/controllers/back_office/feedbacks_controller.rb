module BackOffice
  class FeedbacksController < BaseController
    def index
      authorize [ :back_office, :feedbacks ], :index?
      @by_feature = Accounts::Feedbacks.by_feature
    end
  end
end

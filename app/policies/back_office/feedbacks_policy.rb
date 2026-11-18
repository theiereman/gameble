module BackOffice
  class FeedbacksPolicy < ApplicationPolicy
    def index? = administrator?
  end
end

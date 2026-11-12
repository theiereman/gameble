module BackOffice
  class ChartPublicationPolicy < ApplicationPolicy
    def publish? = administrator?

    def unpublish? = administrator?
  end
end

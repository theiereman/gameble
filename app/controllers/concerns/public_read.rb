module PublicRead
  extend ActiveSupport::Concern

  private
    def public_read?
      request.get? || request.head?
    end
end

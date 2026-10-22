class SitemapsController < ApplicationController
  include PublicRead

  PAGES = %i[home_path legal_path].freeze

  def show
    authorize :page, :show?
    expires_in 1.hour, public: true
    @pages = PAGES.map { |route| helpers.language_alternates(route) }
  end
end

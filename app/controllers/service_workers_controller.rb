class ServiceWorkersController < ApplicationController
  include PublicRead

  # A worker script is fetched as a non-XHR JavaScript GET, which forgery protection refuses as cross-origin.
  skip_forgery_protection

  def show
    authorize :service_worker, :show?

    render template: "pwa/service-worker", layout: false, content_type: "text/javascript"
  end
end

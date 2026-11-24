class ServiceWorkersController < ApplicationController
  include PublicRead

  # A worker script is fetched as a non-XHR JavaScript GET, which forgery protection refuses as cross-origin.
  skip_forgery_protection

  # The browser checks for a new worker while a form's redirect is under way: a session cookie written back from the old state would drop the flash.
  skip_before_action :note_presence
  before_action { request.session_options[:skip] = true }

  def show
    authorize :service_worker, :show?

    render template: "pwa/service-worker", layout: false, content_type: "text/javascript"
  end
end

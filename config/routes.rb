Rails.application.routes.draw do
  # Define your application routes per the DSL in https://guides.rubyonrails.org/routing.html

  # Reveal health status on /up that returns 200 if the app boots with no exceptions, otherwise 500.
  # Can be used by load balancers and uptime monitors to verify that the app is live.
  get "up" => "rails/health#show", as: :rails_health_check

  # Render dynamic PWA files from app/views/pwa/* (remember to link manifest in application.html.erb)
  # get "manifest" => "rails/pwa#manifest", as: :pwa_manifest
  # get "service-worker" => "rails/pwa#service_worker", as: :pwa_service_worker

  # Every page lives under its locale, the first segment of the URL (AD-18).
  scope ":locale", locale: /en|fr/ do
    root "pages#home", as: :home

    # Staff only (R9): moderators and administrators.
    get "back-office" => "back_office/dashboard#show", as: :back_office

    # The Steam import runs (AD-19), administrators only.
    scope "back-office", module: :back_office, as: :back_office do
      resources :import_runs, path: "import-runs", only: %i[index show create] do
        post :resume, on: :member
      end

      # The catalog seasons (AD-5), administrators only.
      resources :seasons, only: :index do
        post :publish, on: :collection
      end
    end
  end

  # The job queue (R7), administrators only: Mission Control Jobs behind
  # BackOffice::JobsBaseController. Engine routes, outside the locale scope.
  mount MissionControl::Jobs::Engine, at: "/back-office/jobs"

  # Steam sign-in (AD-14). OmniAuth answers POST /auth/steam itself; Steam
  # comes back to the callback, and any failure lands on /auth/failure.
  # rack-openid turns Steam's GET back into the POST that omniauth-openid
  # asked for (`_method=post` in return_to), so the callback takes both.
  match "auth/steam/callback" => "sessions#create", as: :steam_callback, via: %i[get post]
  get "auth/failure" => "sessions#failure", as: :auth_failure
  resource :session, only: :destroy

  # "/" sends a first visit to the locale its browser prefers.
  root "locales#redirect"
end

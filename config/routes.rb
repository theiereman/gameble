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

    # Opening a pack from the hub, and the list of its cards (AD-15: by token).
    resources :packs, only: %i[create show], param: :token
    # The booster screen (EXPERIENCE.md, Ouverture de booster): the island
    # sends the opening exchange to packs#create.
    resource :booster, only: :show

    # The collection, reached from the hub's menu: the whole season (CAP-6).
    resource :library, controller: :library, only: :show
    # The collection of one set, by kind and key (AD-15).
    get "library/:kind/:key" => "library#set", as: :library_set, constraints: { kind: /tome|publisher|best_of_year/ }
    # The collection's watermark (AD-26): the page posts the latest gain it
    # showed as new.
    post "library/seen" => "collection_seen#create", as: :library_seen

    # A player's public profile (CAP-8), by their token (AD-15: 24 base58
    # characters, as has_secure_token makes them): their library, and one of
    # their sets opened beside its shelf.
    resources :brothers, only: :show, param: :token, controller: :public_profiles,
      constraints: { token: /[1-9A-HJ-NP-Za-km-z]{24}/ }
    get "brothers/:token/library/:kind/:key" => "public_profiles#set", as: :brother_set,
      constraints: { token: /[1-9A-HJ-NP-Za-km-z]{24}/, kind: /tome|publisher|best_of_year/ }
    # The share links of story 4.5, which named the sharer's token, lead to
    # the card's own page (CAP-9: a shared link shows only the card), on the
    # public base (PUBLIC_URL), never the request's Host. The token is
    # ignored, never looked up.
    old_share_link = lambda do |params, _request|
      path = "/#{params[:locale]}/cards/#{ActionDispatch::Journey::Router::Utils.escape_segment(params[:slug])}"
      path += "/seasons/#{params[:number]}" if params[:number]
      "#{Rails.configuration.x.public_url}#{path}"
    end
    get "brothers/:token/cards/:slug" => redirect(&old_share_link),
      constraints: { token: /[1-9A-HJ-NP-Za-km-z]{24}/ }
    get "brothers/:token/cards/:slug/seasons/:number" => redirect(&old_share_link),
      constraints: { token: /[1-9A-HJ-NP-Za-km-z]{24}/, number: /\d+/ }

    # A card's detail (CAP-7), by its slug (AD-15): in the published season,
    # or in the season numbered (the form a share link takes, CAP-9).
    get "cards/:slug" => "cards#show", as: :card
    get "cards/:slug/seasons/:number" => "cards#show", as: :card_season, constraints: { number: /\d+/ }

    # Collecting the daily bonus from the hub (CAP-16).
    resource :daily_bonus, path: "daily-bonus", only: :create

    # The player's settings (EXPERIENCE.md, Profil et paramètres): language,
    # reduced motion and sign-out. GET reads (AD-11); PATCH writes.
    resource :settings, only: %i[show update]
    # The profile visibility row of the settings (CAP-14).
    patch "settings/visibility" => "settings#visibility", as: :settings_visibility
    # The Friends screen (CAP-10): the player's friends and friend code.
    resource :friends, only: :show
    # The phone's PLUS tab: the rest of the ship (EXPERIENCE.md, PLUS rows).
    get "more" => "pages#more", as: :more

    # Staff only (R9): moderators and administrators.
    get "back-office" => "back_office/dashboard#show", as: :back_office

    # The Steam import runs (AD-19), administrators only.
    scope "back-office", module: :back_office, as: :back_office do
      resources :import_runs, path: "import-runs", only: %i[index show create] do
        post :resume, on: :member
        post :rescore, on: :member
        post :abandon, on: :member
      end

      # The catalog seasons (AD-5), administrators only.
      resources :seasons, only: :index do
        post :publish, on: :collection
      end

      # The card preview, both renderers side by side, administrators only.
      resources :cards, only: :index
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

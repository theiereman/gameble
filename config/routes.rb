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
    resource :packs_chip, path: "packs-chip", only: :show

    # The collection, reached from the hub's menu: its entry, the player's
    # sets; the grid of every card of the season.
    resource :library, controller: :library, only: :show
    get "library/cards" => "library#cards", as: :library_cards
    # One set's album, by kind and key, never by id.
    get "library/:kind/:key" => "library#set", as: :library_set, constraints: { kind: /theme|franchise|studio|hall_of_fame|ufo/ }
    # The collection's watermark: the page posts the latest gain it showed
    # as new.
    post "library/seen" => "collection_seen#create", as: :library_seen

    # A player's public profile, by their token (24 base58 characters, as
    # has_secure_token makes them, never an id): their sets, and one of
    # their sets' albums.
    resources :brothers, only: :show, param: :token, controller: :public_profiles,
      constraints: { token: /[1-9A-HJ-NP-Za-km-z]{24}/ }
    # Reporting a player from their profile, by token.
    post "brothers/:token/report" => "reports#create", as: :brother_report,
      constraints: { token: /[1-9A-HJ-NP-Za-km-z]{24}/ }
    get "brothers/:token/library/:kind/:key" => "public_profiles#set", as: :brother_set,
      constraints: { token: /[1-9A-HJ-NP-Za-km-z]{24}/, kind: /theme|franchise|studio|hall_of_fame|ufo/ }
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
    post "cards/:slug/seasons/:number/repost" => "reposts#create", as: :card_repost

    # Collecting the daily bonus from the hub (CAP-16).
    resource :daily_bonus, path: "daily-bonus", only: :create
    post "goal-rewards/:week" => "goal_rewards#create", as: :goal_reward, constraints: { week: /\d{4}-\d{2}-\d{2}/ }
    resource :welcome, only: :destroy

    # The player's settings (EXPERIENCE.md, Profil et paramètres): language,
    # reduced motion and sign-out. GET reads (AD-11); PATCH writes.
    resource :settings, only: %i[show update]
    # The profile visibility row of the settings (CAP-14).
    patch "settings/visibility" => "settings#visibility", as: :settings_visibility
    # Deleting the player's own account, from the settings' delete dialog
    # (CAP-14).
    resource :account, only: :destroy
    resource :data_export, only: %i[show create], path: "settings/export", as: :settings_export
    resource :friends, only: :show
    resource :achievements, only: :show
    get "friends/:token" => "friend_profiles#show", as: :friend_profile,
      constraints: { token: /[1-9A-HJ-NP-Za-km-z]{24}/ }
    post "friends/:token/remove" => "friends#remove", as: :remove_friend,
      constraints: { token: /[1-9A-HJ-NP-Za-km-z]{24}/ }

    # The activity feed (CAP-13): public, read only.
    get "feed" => "feeds#show", as: :feed
    post "friends/invitations" => "invitations#create", as: :invitations
    post "friends/invitations/:token/accept" => "invitations#accept", as: :accept_invitation,
      constraints: { token: /[1-9A-HJ-NP-Za-km-z]{24}/ }
    post "friends/invitations/:token/ignore" => "invitations#ignore", as: :ignore_invitation,
      constraints: { token: /[1-9A-HJ-NP-Za-km-z]{24}/ }
    post "friends/invitations/:token/cancel" => "invitations#cancel", as: :cancel_invitation,
      constraints: { token: /[1-9A-HJ-NP-Za-km-z]{24}/ }
    get "invite/:token" => "invite_links#show", as: :invite_link,
      constraints: { token: /[1-9A-HJ-NP-Za-km-z]{24}/ }
    post "invite/:token" => "invite_links#create",
      constraints: { token: /[1-9A-HJ-NP-Za-km-z]{24}/ }
    resources :trades, only: %i[index show new create], param: :token,
      constraints: { token: /[1-9A-HJ-NP-Za-km-z]{24}/ } do
      collection do
        get :faces
      end
      member do
        get :counter, action: :edit
        post :counter
        post :accept
        post :decline
        post :cancel
      end
    end
    # The phone's PLUS tab: the rest of the ship (EXPERIENCE.md, PLUS rows).
    get "more" => "pages#more", as: :more
    get "legal" => "pages#legal", as: :legal
    # The rules of the game, readable signed out.
    get "how-it-works" => "pages#how_it_works", as: :how_it_works

    # Staff only (R9): moderators and administrators.
    get "back-office" => "back_office/dashboard#show", as: :back_office

    # The back-office pages, staff only; each policy says which staff role.
    scope "back-office", module: :back_office, as: :back_office do
      # The Steam import runs, administrators only.
      resources :import_runs, path: "import-runs", only: %i[index show create] do
        post :resume, on: :member
        post :rescore, on: :member
        post :abandon, on: :member
      end

      resources :seasons, only: %i[index show], param: :number, constraints: { number: /\d+/ } do
        post :publish, on: :collection
      end

      # The landing's roadmap, administrators only: the milestones of the
      # initiative's epics, and the stories under each, by token.
      resources :roadmap_milestones, path: "roadmap", param: :token, only: %i[index edit update],
        constraints: { token: /[1-9A-HJ-NP-Za-km-z]{24}/ } do
        post :move, on: :member
        resources :roadmap_stories, path: "stories", only: %i[new create],
          constraints: { roadmap_milestone_token: /[1-9A-HJ-NP-Za-km-z]{24}/ }
      end
      resources :roadmap_stories, path: "roadmap/stories", param: :token, only: %i[edit update destroy],
        constraints: { token: /[1-9A-HJ-NP-Za-km-z]{24}/ } do
        post :move, on: :member
      end

      # The card preview, both renderers side by side, administrators only.
      resources :cards, only: :index

      # Moderation, moderators and administrators: the queue of reported
      # players, every player to search, the banned players, each by token,
      # and the history of every ban, lifted ban and dismissal.
      resources :players, only: :index
      resources :reports, only: :index
      post "reports/:token/dismiss" => "reports#dismiss", as: :dismiss_reports,
        constraints: { token: /[1-9A-HJ-NP-Za-km-z]{24}/ }
      resources :bans, only: %i[index create destroy], param: :token,
        constraints: { token: /[1-9A-HJ-NP-Za-km-z]{24}/ }
      get "history" => "history#index", as: :history
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

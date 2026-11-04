Rails.application.routes.draw do
  # Define your application routes per the DSL in https://guides.rubyonrails.org/routing.html

  # Reveal health status on /up that returns 200 if the app boots with no exceptions, otherwise 500.
  # Can be used by load balancers and uptime monitors to verify that the app is live.
  get "up" => "rails/health#show", as: :rails_health_check

  # Render dynamic PWA files from app/views/pwa/* (remember to link manifest in application.html.erb)
  # get "manifest" => "rails/pwa#manifest", as: :pwa_manifest
  # get "service-worker" => "rails/pwa#service_worker", as: :pwa_service_worker

  # Every page lives under its locale, the first segment of the URL.
  scope ":locale", locale: /en|fr/ do
    root "pages#home", as: :home
    # The landing once lived here; its links lead to the root.
    get "landing", to: redirect("/%{locale}", status: 301)
    # Where a visitor chooses how to sign in; the sign-in buttons across the site lead here.
    get "sign-in" => "sign_ins#show", as: :sign_in
    # Where Clerk returns to after an OAuth hop; the same screen, finishing the sign-in.
    get "sign-in/callback" => "sign_ins#show", as: :sign_in_callback, defaults: { mode: "callback" }
    # The browser posts here once Clerk holds a session: the server checks it and opens its own.
    post "auth/clerk" => "clerk_sessions#create", as: :clerk_session
    # A signed-in player adding Discord, Google or an email code to their account.
    post "settings/sign-ins" => "sign_in_methods#create", as: :settings_sign_ins
    # A signed-in player without Steam asking to link it: the Steam return then adds it to their account.
    post "settings/steam" => "steam_links#create", as: :settings_steam
    # The public roadmap, every milestone and story staff chose to show.
    get "roadmap" => "roadmaps#show", as: :roadmap
    # The visitor's motion switch, written into the motion cookie.
    post "motion" => "motions#create", as: :motion

    # Opening a pack from the hub, and the list of its cards, by token.
    resources :packs, only: %i[create show], param: :token
    # The booster posts how a capsule was revealed once its last card is face up.
    post "packs/:token/reveal" => "pack_reveals#create", as: :pack_reveal, constraints: { token: /[1-9A-HJ-NP-Za-km-z]{24}/ }
    # The booster screen, where a pack is opened: its root controller sends the
    # opening exchange to packs#create.
    resource :booster, only: :show
    # What an empty reserve proposes, loaded in a frame once the reserve runs out.
    get "booster/next-steps" => "booster_next_steps#show", as: :booster_next_steps
    resource :packs_chip, path: "packs-chip", only: :show
    # What is new for the player, the lines of the header's bell, in a frame.
    resource :bell, only: :show

    # The collection, reached from the hub's menu: its entry, the player's
    # sets; the grid of every card of the season.
    resource :library, controller: :library, only: :show
    get "library/in-progress" => "library#in_progress", as: :library_in_progress
    get "library/cards" => "library#cards", as: :library_cards
    # The sets a player gathers themselves, by token; the editor's games
    # arrive page by page in a frame, searched and filtered.
    get "library/custom-sets/games" => "custom_sets#games", as: :custom_set_games
    resources :custom_sets, path: "library/custom-sets", only: %i[create show update destroy], param: :token,
      constraints: { token: /[1-9A-HJ-NP-Za-km-z]{24}/ }
    # A player's goals, each named by its set: a kind and key, or a custom
    # set's token, never a position.
    post "library/goals" => "goals#create", as: :library_goals
    delete "library/goals" => "goals#destroy"
    # One set's album, by kind and key, never by id.
    get "library/:kind/:key" => "library#set", as: :library_set, constraints: { kind: Catalog::SetKind::PATTERN }
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
    # Inviting a player from their profile, or accepting their invitation.
    post "brothers/:token/invitation" => "brother_invitations#create", as: :brother_invitation,
      constraints: { token: /[1-9A-HJ-NP-Za-km-z]{24}/ }
    get "brothers/:token/library" => "public_profiles#collection", as: :brother_collection,
      constraints: { token: /[1-9A-HJ-NP-Za-km-z]{24}/ }
    get "brothers/:token/library/:kind/:key" => "public_profiles#set", as: :brother_set,
      constraints: { token: /[1-9A-HJ-NP-Za-km-z]{24}/, kind: Catalog::SetKind::PATTERN }
    # The old share links, which named the sharer's token, lead to the
    # card's own page (a shared link shows only the card), on the public
    # base (PUBLIC_URL), never the request's Host. The token is ignored,
    # never looked up.
    old_share_link = lambda do |params, _request|
      path = "/#{params[:locale]}/cards/#{ActionDispatch::Journey::Router::Utils.escape_segment(params[:slug])}"
      path += "/seasons/#{params[:number]}" if params[:number]
      "#{Rails.configuration.x.public_url}#{path}"
    end
    get "brothers/:token/cards/:slug" => redirect(&old_share_link),
      constraints: { token: /[1-9A-HJ-NP-Za-km-z]{24}/ }
    get "brothers/:token/cards/:slug/seasons/:number" => redirect(&old_share_link),
      constraints: { token: /[1-9A-HJ-NP-Za-km-z]{24}/, number: /\d+/ }

    # A card's detail, by its slug, never by id: in the published season,
    # or in the season numbered (the form a share link takes).
    get "cards/:slug" => "cards#show", as: :card
    get "cards/:slug/seasons/:number" => "cards#show", as: :card_season, constraints: { number: /\d+/ }
    post "cards/:slug/seasons/:number/repost" => "reposts#create", as: :card_repost
    # Adding a held card to the player's profile showcase, taking it out, or
    # moving it one place earlier or later.
    post "cards/:slug/seasons/:number/showcase" => "showcases#create", as: :card_showcase
    patch "cards/:slug/seasons/:number/showcase" => "showcases#update"
    delete "cards/:slug/seasons/:number/showcase" => "showcases#destroy"
    post "cards/:slug/seasons/:number/trade" => "card_trades#create", as: :card_trade, constraints: { number: /\d+/ }

    # Collecting the daily bonus from the hub.
    resource :daily_bonus, path: "daily-bonus", only: :create
    post "goal-rewards/:week" => "goal_rewards#create", as: :goal_reward, constraints: { week: /\d{4}-\d{2}-\d{2}/ }
    resource :welcome, only: :destroy
    # Closing the red announcement banner: remembered for the player, or in a cookie for a visitor.
    post "announcements/:token/dismissal" => "announcement_dismissals#create", as: :announcement_dismissal,
      constraints: { token: /[1-9A-HJ-NP-Za-km-z]{24}/ }
    # The screen shown once before the hub after a season is published; its
    # POST receives the allocation if pending and marks it seen.
    resource :season_allocation, path: "season-allocation", only: %i[show create]

    # The player's settings: language, reduced motion and sign-out. GET
    # reads; PATCH writes.
    resource :settings, only: %i[show update]
    # The player's dressing once had its own page; the Me page now holds it.
    get "personalization", to: redirect("/%{locale}/me", status: 301), as: :personalization
    patch "personalization/title" => "profile_titles#update", as: :personalization_title
    patch "personalization/back" => "card_backs#update", as: :personalization_back
    # The profile visibility row of the settings.
    patch "settings/visibility" => "settings#visibility", as: :settings_visibility
    # The name row of the settings, for a player whose name does not come from Steam.
    patch "settings/name" => "settings#name", as: :settings_name
    # The Steam library sync row of the settings, for a player with a Steam identity.
    patch "settings/steam-library" => "settings#steam_library", as: :settings_steam_library
    post "settings/steam-library/sync" => "settings#sync_steam_library", as: :settings_steam_library_sync
    # Deleting the player's own account, from the settings' delete dialog.
    resource :account, only: :destroy
    resource :data_export, only: %i[show create], path: "settings/export", as: :settings_export
    resource :friends, only: :show
    resource :achievements, only: :show
    post "achievements/:achievement/claim" => "achievement_claims#create", as: :claim_achievement,
      constraints: { achievement: /[a-z0-9_]+/ }
    get "friends/:token" => "friend_profiles#show", as: :friend_profile,
      constraints: { token: /[1-9A-HJ-NP-Za-km-z]{24}/ }
    post "friends/:token/remove" => "friends#remove", as: :remove_friend,
      constraints: { token: /[1-9A-HJ-NP-Za-km-z]{24}/ }

    # The activity feed: public, read only.
    get "feed" => "feeds#show", as: :feed
    # An entry's reactions, by its token: the bar a lazy frame loads, a player's reaction and its removal.
    get "feed/entries/:token/reactions" => "reactions#show", as: :feed_entry_reactions,
      constraints: { token: /\h{8}-\h{4}-\h{4}-\h{4}-\h{12}/ }
    post "feed/entries/:token/reaction" => "reactions#create", as: :feed_entry_reaction,
      constraints: { token: /\h{8}-\h{4}-\h{4}-\h{4}-\h{12}/ }
    delete "feed/entries/:token/reaction" => "reactions#destroy",
      constraints: { token: /\h{8}-\h{4}-\h{4}-\h{4}-\h{12}/ }
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
    post "trades/:token/seen" => "trade_seens#create", as: :trade_seen,
      constraints: { token: /[1-9A-HJ-NP-Za-km-z]{24}/ }
    # The phone's Social tab opens this menu; its Me tab the player's own profile.
    get "social" => "pages#social", as: :social
    get "me" => "own_profiles#show", as: :me
    get "more", to: redirect("/%{locale}/me", status: 301), as: :more
    get "legal" => "pages#legal", as: :legal
    get "credits" => "pages#credits", as: :credits
    # The rules of the game, readable signed out.
    get "how-it-works" => "pages#how_it_works", as: :how_it_works

    # Staff only: moderators and administrators.
    get "back-office" => "back_office/dashboard#show", as: :back_office

    # The back-office pages, staff only; each policy says which staff role.
    scope "back-office", module: :back_office, as: :back_office do
      # The Steam import runs, administrators only.
      resources :import_runs, path: "import-runs", only: %i[index show create] do
        post :resume, on: :member
        post :rescore, on: :member
        post :abandon, on: :member
        post :promote, on: :member
        post :discard, on: :member
      end

      resources :seasons, only: %i[index show], param: :number, constraints: { number: /\d+/ } do
        post :publish, on: :collection
      end

      # The landing's roadmap, administrators only: every milestone and its
      # stories in one form, saved at once, with a live preview of the landing.
      resource :roadmap, only: :show do
        post :preview
      end
      post "roadmap" => "roadmaps#update", as: :save_roadmap

      # The themes of the catalog and the Steam tags the draft's cards carry,
      # administrators only: each tag is attached to a theme, made a theme or
      # dismissed; a theme is renamed by its token.
      resources :themes, param: :token, only: %i[index create update],
        constraints: { token: /[1-9A-HJ-NP-Za-km-z]{24}/ } do
        post :attach, on: :collection
        post :dismiss, on: :collection
      end

      # The announcements shown to every player on a red banner, administrators
      # only: written in both languages, at most one shown at a time.
      resources :announcements, param: :token, only: %i[index create update],
        constraints: { token: /[1-9A-HJ-NP-Za-km-z]{24}/ } do
        post :publish, on: :member
        post :withdraw, on: :member
      end

      # The card preview, both renderers side by side, administrators only.
      resources :cards, only: :index

      # Moderation, moderators and administrators: the queue of reported
      # players, every player to search, the banned players, each by token,
      # and the history of every ban, lifted ban, dismissal and erasure.
      resources :players, only: %i[index destroy], param: :token,
        constraints: { token: /[1-9A-HJ-NP-Za-km-z]{24}/ }
      resources :reports, only: :index
      post "reports/:token/dismiss" => "reports#dismiss", as: :dismiss_reports,
        constraints: { token: /[1-9A-HJ-NP-Za-km-z]{24}/ }
      resources :bans, only: %i[index create destroy], param: :token,
        constraints: { token: /[1-9A-HJ-NP-Za-km-z]{24}/ }
      get "history" => "history#index", as: :history
    end
  end

  # The job queue, administrators only: Mission Control Jobs behind
  # BackOffice::JobsBaseController. Engine routes, outside the locale scope.
  mount MissionControl::Jobs::Engine, at: "/back-office/jobs"

  # Steam sign-in. OmniAuth answers POST /auth/steam itself; Steam
  # comes back to the callback, and any failure lands on /auth/failure.
  # rack-openid turns Steam's GET back into the POST that omniauth-openid
  # asked for (`_method=post` in return_to), so the callback takes both.
  match "auth/steam/callback" => "sessions#create", as: :steam_callback, via: %i[get post]
  get "auth/failure" => "sessions#failure", as: :auth_failure
  resource :session, only: :destroy

  # A shared card's preview image, by its token (never an id), the same in
  # every language: outside the locale scope, built with `locale: nil`.
  get "share-images/:token.png" => "share_images#show", as: :share_image, format: false,
    constraints: { token: /[1-9A-HJ-NP-Za-km-z]{24}/ }

  get "robots.txt" => "robots#show", format: false
  get "llms.txt" => "llms#show", format: false
  get "sitemap.xml" => "sitemaps#show", defaults: { format: :xml }, format: false

  # "/" sends a first visit to the locale its browser prefers.
  root "locales#redirect"
end

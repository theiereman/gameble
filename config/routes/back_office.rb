scope "back-office", module: :back_office, as: :back_office do
  # The Steam import runs, administrators only.
  resources :import_runs, path: "import-runs", only: %i[index show create] do
    post :resume, on: :member
    post :rescore, on: :member
    post :abandon, on: :member
    post :promote, on: :member
    post :discard, on: :member
  end

  resources :code_contributions, path: "code-contributions", only: :create

  resources :seasons, only: %i[index show update], param: :number, constraints: { number: /\d+/ } do
    post :publish, on: :collection
  end

  # The landing's roadmap, administrators only: every milestone and its
  # stories in one form, saved at once, with a live preview of the landing;
  # Claude fills the English lines left empty.
  resource :roadmap, only: :show do
    post :preview
    post :translate
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

  # The notes of each production release, administrators only: written in
  # both languages from the release's commits, which Claude can condense and
  # translate, shown once to every player when production runs that release.
  resources :release_notes, path: "release-notes", param: :token, only: %i[index create edit],
    constraints: { token: /[1-9A-HJ-NP-Za-km-z]{24}/ } do
    post :preview, on: :collection
    post :translate, on: :collection
    post :save, on: :member
    post :state, on: :member
    post :condense, on: :member
  end

  # The market, staff only: its state and, for administrators, the opening
  # form with both legal confirmations and the announcement that follows, the
  # closing form with its announcement, and the economy settings form; beside
  # them the economy's health, read from the nightly snapshots, and the
  # accounts that open or trade like an alt account, read from the nightly signals.
  resource :market, only: :show
  resource :market_health, path: "market/health", controller: "market_health", only: :show
  resource :market_signals, path: "market/signals", only: :show
  resource :market_opening, path: "market/opening", only: :create
  resource :market_closing, path: "market/closing", only: :create
  resource :market_settings, path: "market/settings", only: :create
  # The public charts' publication switches, administrators only.
  post "market/charts/:kind/publish" => "chart_publications#publish", as: :publish_chart,
    constraints: { kind: /reactor|rarity_prices|edition_sales/ }
  post "market/charts/:kind/unpublish" => "chart_publications#unpublish", as: :unpublish_chart,
    constraints: { kind: /reactor|rarity_prices|edition_sales/ }

  # How duels play, staff only: the finished duels of one rules version, live apart from practice.
  resource :duels, only: :show

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
  # What players wrote about the features staff asked them to test, administrators only.
  resources :feedbacks, only: :index
end

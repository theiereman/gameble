# The links of a player's list of sets (CAP-8), as locals for the
# `public_profiles/set_list` partial: a tab's URL from its name, a set's URL
# from its kind, key and page.
module ShelvesHelper
  # A player's public profile, by their token, open on the tab `kind` among
  # `tabs`: the Started tab first (its URL without a kind), and sets opened
  # beside the Started shelf (`tab=started`) when it is the one open.
  def profile_shelf_links(token, kind, tabs)
    started = PublicProfilesController::STARTED
    tab = (started if kind == started)
    { tabs:,
      tab_url: ->(tab_kind) { brother_path(token, kind: (tab_kind unless tab_kind == started)) },
      set_url: ->(set_kind, key, page) { brother_set_path(token, kind: set_kind, key:, page:, tab:) } }
  end
end

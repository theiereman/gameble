# The links of a shelf of sets (CAP-6, CAP-8), as locals for the
# `library/shelf` partial: a tab's URL from its name, a set's URL from its
# kind, key and shelf page.
module ShelvesHelper
  # A player's public profile, by their token, open on the tab `kind`: the
  # Started tab first (its URL without a kind), spines marked complete, and
  # sets opened beside the Started shelf (`tab=started`) when it is the one
  # open.
  def profile_shelf_links(token, kind)
    started = PublicProfilesController::STARTED
    tab = (started if kind == started)
    { tabs: PublicProfilesController::TABS, mark_complete: true,
      tab_url: ->(tab_kind) { brother_path(token, kind: (tab_kind unless tab_kind == started)) },
      set_url: ->(set_kind, key, page) { brother_set_path(token, kind: set_kind, key:, page:, tab:) } }
  end
end

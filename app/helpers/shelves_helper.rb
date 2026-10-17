# The links of a player's list of sets beside one of their sets, as locals
# for the `public_profiles/set_list` partial: a tab's URL keeps the set open
# beside that tab's shelf; a set's URL from its kind, key and page keeps the
# tab open.
module ShelvesHelper
  def profile_shelf_links(token, kind, tabs, set)
    { tabs:,
      tab_url: ->(tab_kind) { brother_set_path(token, kind: set.kind, key: set.key, tab: (tab_kind unless tab_kind == set.kind)) },
      set_url: ->(set_kind, key, page) { brother_set_path(token, kind: set_kind, key:, page:, tab: (kind unless kind == set_kind)) } }
  end
end

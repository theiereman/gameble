# Pagy (Consistency Conventions: Pagination). Its own dictionary is replaced
# by config/locales/pagy/{en,fr}.yml, in the Brotherhood's voice (AD-18);
# the request's locale is set in ApplicationController.
Pagy::I18n.pathnames << Rails.root.join("config/locales/pagy")

Pagy::OPTIONS.freeze

# Base class of every Active Record model. It lives in the `lib` package so
# pack models can inherit it without depending on the web layer (AD-2).
class ApplicationRecord < ActiveRecord::Base
  primary_abstract_class
end

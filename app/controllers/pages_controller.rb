class PagesController < ApplicationController
  def home
    authorize :page, :show?
  end
end

class MarketsController < ApplicationController
  include PublicRead

  def show
    authorize :market, :show?
  end
end

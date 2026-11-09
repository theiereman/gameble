class RarityLegendsController < ApplicationController
  def show
    authorize :rarity_legend, :show?

    respond_to do |format|
      format.turbo_stream
    end
  end
end

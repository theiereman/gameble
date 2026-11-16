class ShowcaseEditorsController < ApplicationController
  include CollectionGridLoading
  include ChosenCards

  def show
    authorize :showcase, :edit?
    @chosen = chosen_cards(current_player)
    @season = Catalog::PublishedSeason.call
    return if @season.nil?

    @grid = collection_grid(@season, params)
    load_grid(@grid, states: [ "owned" ])
  end
end

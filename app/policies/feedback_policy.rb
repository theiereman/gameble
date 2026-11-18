class FeedbackPolicy < ApplicationPolicy
  def new? = player?
  def create? = player?
end

class TradePolicy < ApplicationPolicy
  def index? = player?
  def show? = player?
  def new? = player?
  def create? = player?
  def counter? = player?
  def accept? = player?
  def decline? = player?
  def cancel? = player?
end

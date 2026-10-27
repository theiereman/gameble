module Steam
  # Published when an administrator reopens the latest completed import run
  # on its cards step to rewrite the draft's prestige scores (AD-10).
  # data = { import_run_id: }.
  class CardsRescoreStarted < RubyEventStore::Event
  end
end

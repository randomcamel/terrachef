module Terrachef
class CheffifiedToolCompiler

  class << self
    def respondables
      raise "Your subclass of #{self} must implement self.respondables."
    end

    def top_level_items
      raise "Your subclass of #{self} must implement self.top_level_items."
    end
  end

  def respondables; self.class.respondables; end

end
end
module Terrachef
class CheffifiedToolCompiler

  class << self
    def respondables
      top_levels
    end

    def top_levels
      raise "Your subclass of #{self} must implement self.top_levels."
    end

    # these are to avoid #instance_variable_get, which just looks gross.
    def define_top_level_methods
      top_levels.each { |sym| attr_accessor self.plural(sym) }
    end
  end

  def initialize
    self.class.define_top_level_methods
  end

  def respondables
    self.class.respondables
  end
end
end
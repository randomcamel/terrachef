module Terrachef
class CheffifiedToolCompiler
  def self.respondables
    raise "Your subclass of #{self} must implement self.respondables."
  end

  def respondables; self.class.respondables; end

end
end
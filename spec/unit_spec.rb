require 'spec_helper'

describe TerraformCompile do
  context "helper methods" do
    def plural(thing)
      TerraformCompile.plural(thing)
    end

    it "pluralizes strings into symbols" do
      expect(plural("blort")).to eq(:blorts)
      expect(plural(:narf)).to eq(:narfs)

      # make sure we're not being clever.
      expect(plural("hrorfs")).to eq(:hrorfss)
    end
  end
end
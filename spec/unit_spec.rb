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

describe TerraformAttributes do
  context "parsing attributes" do
    it "throws an exception when passed arguments of the wrong type" do
      expect { TerraformAttributes.new     }.to raise_error(ArgumentError, /Must pass a block/)
      expect { TerraformAttributes.new(42) }.to raise_error(ArgumentError, /wrong number/)
    end

    it "throws an exception when given a block with no attributes" do
      block = Proc.new { 42 }
      expect { TerraformAttributes.new(&block) }.to raise_error(/No attribute-value pairs found/)
    end

  end
end

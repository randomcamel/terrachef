# ------------------------------------------------------------------------
# this is a separate class because its #method_missing behaves differently. we could do the same thing with
# some fancy footwork in TerraformCompile, but only at the cost of clarity and testability.
class AttributePairs

  attr_reader :attr_kv_pairs

  # given a block of stuff like this:
  # 
  # an_attribute "some value"
  # 
  # return a hash of { :an_attribute => "some value" }
  def initialize(&attributes_block)
    raise ArgumentError, "Must pass a block to #{self.class}" unless attributes_block
    @attr_kv_pairs = {}
    instance_eval(&attributes_block)
    if attr_kv_pairs.size == 0
      raise RuntimeError, "No attribute-value pairs found: must use the format 'my_attribute 'my_value'."
    end
  end

  def method_missing(name, value)
    new_kv = { name => value }

    # gracefully handle repeated attributes.
    if attr_kv_pairs.has_key?(name)

      # is it already an Array?
      if attr_kv_pairs[name].class == Array
        attr_kv_pairs[name] << value
      # nope, this is the first repetition.
      else
        attr_kv_pairs[name] = [attr_kv_pairs[name], value]
      end

    else
      # just treat it like a single k-v pair.
      @attr_kv_pairs.merge!(new_kv)
    end
  end

  def respond_to_missing?(method_name, include_private=false)
    true
  end
end

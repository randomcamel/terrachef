unless Gem::Requirement.new(">= 12.5").satisfied_by?(Gem::Version.new(Chef::VERSION))
  raise "The Terrachef cookbook does not support chef versions older than Chef 12.5.0"
end

begin
  terrachef_gem = Gem::Specification.find_by_name("terrachef")
rescue Gem::LoadError
end

if terrachef_gem
  # The gem is installed.
  require 'chef_compat'
  # Make sure the version installed is more recent than the cookbook so there's no confusion.
  version_rb = IO.read(File.expand_path("../../files/lib/terrachef/version.rb", __FILE__))
  raise "Version file not in correct format" unless version_rb =~ /VERSION\s*=\s*'([^']+)'/
  version = $1
  if Gem::Version.new(version) > Gem::Version.new(Terrachef::VERSION)
    raise "Installed terrachef gem #{Terrachef::VERSION} is *older* than the terrachef cookbook. Please install a more recent version."
  end
  Chef::Log.info("Using terrachef gem version #{Terrachef::VERSION} installed on system instead of terrachef cookbook (which is version #{version}).")
else

  # The cookbook is the only copy; load the cookbook.
  $:.unshift File.expand_path("../../files/lib", __FILE__)
  begin
    require 'terrachef'
  rescue LoadError
    raise "Could not find my own library file, so...that's kind of weird."
  end
end

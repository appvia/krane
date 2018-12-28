
lib = File.expand_path("../lib", __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require "rbac_visualiser/version"

Gem::Specification.new do |spec|
  spec.name          = "rbacvis"
  spec.version       = RbacVisualiser::VERSION
  spec.authors       = ["Marcin Ciszak"]
  spec.email         = ["marcin@state.com"]

  spec.summary       = %q{to-do: Write a short summary, because RubyGems requires one.}
  spec.description   = %q{to-do: Write a longer description or delete this line.}

  spec.license       = "mit"

  # Prevent pushing this gem to RubyGems.org. To allow pushes either set the 'allowed_push_host'
  # to allow pushing to a single host or delete this section to allow pushing to any host.
  if spec.respond_to?(:metadata)
    spec.metadata["allowed_push_host"] = "to-do: Set to 'http://mygemserver.com'"
  else
    raise "RubyGems 2.0 or newer is required to protect against " \
      "public gem pushes."
  end

  spec.files         = `git ls-files -z`.split("\x0").reject do |f|
    f.match(%r{^(test|spec|features)/})
  end
  spec.bindir        = "exe"
  spec.executables   = spec.files.grep(%r{^exe/}) { |f| File.basename(f) }
  spec.require_paths = ["lib"]

  spec.add_development_dependency "bundler", "~> 1.16"
  spec.add_development_dependency "rake", "~> 10.0"
  spec.add_development_dependency "rspec", "~> 3.0"
  spec.add_development_dependency('rdoc')
  spec.add_development_dependency('test-unit')
  spec.add_runtime_dependency('commander')
  spec.add_runtime_dependency('colorize')
  spec.add_runtime_dependency('activesupport')
  spec.add_runtime_dependency('hashie')  
  spec.add_runtime_dependency('redisgraph')

end

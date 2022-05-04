
lib = File.expand_path("../lib", __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require "hive/service/version"

Gem::Specification.new do |spec|
  spec.name          = "hive-service"
  spec.version       = Hive::Service::VERSION
  spec.authors       = ["Mohamed Elmenisy"]
  spec.email         = ["mohamed.elmenisy@hive.app"]

  spec.summary       = "Hive service layer"
  spec.license       = "private"

  spec.files         = Dir.chdir(File.expand_path('..', __FILE__)) do
    `git ls-files -z`.split("\x0").reject { |f| f.match(%r{^(test|spec|features)/}) }
  end

  spec.bindir        = "exe"
  spec.executables   = spec.files.grep(%r{^exe/}) { |f| File.basename(f) }
  spec.require_paths = ["lib"]

  spec.add_development_dependency "bundler", "~> 1.17"
  spec.add_development_dependency "rake", "~> 10.0"
  spec.add_development_dependency "rspec", "~> 3.0"
end

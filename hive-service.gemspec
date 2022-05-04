
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

  spec.add_runtime_dependency 'activesupport'
  spec.add_runtime_dependency 'dry-struct'
  spec.add_runtime_dependency 'dry-types'
  spec.add_runtime_dependency 'i18n'

  spec.add_development_dependency 'bundler', '~> 2.0'
end

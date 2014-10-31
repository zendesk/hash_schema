# coding: utf-8
lib = File.expand_path('../lib', __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require 'hash_schema/version'

Gem::Specification.new do |spec|
  spec.name          = "hash_schema"
  spec.version       = HashSchema::VERSION
  spec.authors       = ["Po Chen"]
  spec.email         = ["pchen@zendesk.com"]
  spec.summary       = %q{Validate Hash against Schema}
  spec.description   = <<-DESC
    This gem provides schema building blocks that can be used to define
    complicated hash structures, which can then be used to validate hashes
    that are created by loading json or yml files.
  DESC
  spec.homepage      = "https://github.com/princemaple/hash_schema"
  spec.license       = "MIT"

  spec.files         = `git ls-files -z`.split("\x0")
  spec.executables   = spec.files.grep(%r{^bin/}) { |f| File.basename(f) }
  spec.test_files    = spec.files.grep(%r{^(test|spec|features)/})
  spec.require_paths = ["lib"]

  spec.add_development_dependency "bundler", "~> 1.6"
  spec.add_development_dependency "rake"
  spec.add_development_dependency "bump"
  spec.add_development_dependency "byebug"
end

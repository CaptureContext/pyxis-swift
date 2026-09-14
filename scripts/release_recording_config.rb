#!/usr/bin/env ruby
# Derive CI settings from the authored example without changing its local configuration.
require 'json'
require 'yaml'

root = File.expand_path('..', __dir__)
config = YAML.safe_load(File.read(File.join(root, 'Example/pyxis.yaml')))
config.fetch('xcode')['workspace'] = File.join(root, 'Example/PyxisExample.xcworkspace')
config['devices'] = [{ 'name' => 'iPhone 17 Pro' }]
config['output'] = File.join(root, '.generated/release/recordings')
config['derived_data'] = File.join(root, '.generated/release/DerivedData')
config.delete('storage')
config['archive'] = true
puts JSON.pretty_generate(config)

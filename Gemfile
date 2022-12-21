source('https://rubygems.org')

gemspec

# gem "fastlane", path: "../fastlane"
gem "fastlane", git: "https://github.com/fastlane/fastlane.git", branch: "joshdholtz-asc-api-iaps"

plugins_path = File.join(File.dirname(__FILE__), 'fastlane', 'Pluginfile')
eval_gemfile(plugins_path) if File.exist?(plugins_path)

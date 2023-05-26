source('https://rubygems.org')

gemspec

# gem "fastlane", path: "../fastlane"
gem "fastlane", git: "https://github.com/fastlane/fastlane.git", branch: "joshdholtz-asc-api-iaps"
gem "iso_country_codes"
gem "rest-client"

plugins_path = File.join(File.dirname(__FILE__), 'fastlane', 'Pluginfile')
eval_gemfile(plugins_path) if File.exist?(plugins_path)

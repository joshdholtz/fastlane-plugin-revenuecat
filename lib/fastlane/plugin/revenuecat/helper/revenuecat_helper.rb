require 'fastlane_core/ui/ui'

require 'uri'
require 'net/http'
require 'openssl'
require 'json'

module Fastlane
  UI = FastlaneCore::UI unless Fastlane.const_defined?("UI")

  module Helper
    class RevenuecatHelper
      def self.available_options_google_play
        [
          FastlaneCore::ConfigItem.new(key: :json_key,
                                     env_name: "RC_GOOGLE_JSON_KEY",
                                     short_option: "-j",
                                     conflicting_options: [:issuer, :key, :json_key_data],
                                     optional: true, # this shouldn't be optional but is until --key and --issuer are completely removed
                                     description: "The path to a file containing service account JSON, used to authenticate with Google",
                                     code_gen_sensitive: true,
                                     default_value: CredentialsManager::AppfileConfig.try_fetch_value(:json_key_file),
                                     default_value_dynamic: true,
                                     verify_block: proc do |value|
                                       UI.user_error!("Could not find service account json file at path '#{File.expand_path(value)}'") unless File.exist?(File.expand_path(value))
                                       UI.user_error!("'#{value}' doesn't seem to be a JSON file") unless FastlaneCore::Helper.json_file?(File.expand_path(value))
                                     end),
          FastlaneCore::ConfigItem.new(key: :json_key_data,
                                      env_name: "RC_GOOGLE_JSON_KEY_DATA",
                                      short_option: "-c",
                                      conflicting_options: [:issuer, :key, :json_key],
                                      optional: true,
                                      description: "The raw service account JSON data used to authenticate with Google",
                                      code_gen_sensitive: true,
                                      default_value: CredentialsManager::AppfileConfig.try_fetch_value(:json_key_data_raw),
                                      default_value_dynamic: true,
                                      verify_block: proc do |value|
                                        begin
                                          JSON.parse(value)
                                        rescue JSON::ParserError
                                          UI.user_error!("Could not parse service account json  JSON::ParseError")
                                        end
                                      end),
          FastlaneCore::ConfigItem.new(key: :timeout,
                                      env_name: "RC_GOOGLE_TIMEOUT",
                                      optional: true,
                                      description: "Timeout for read, open, and send (in seconds)",
                                      type: Integer,
                                      default_value: 300),
          FastlaneCore::ConfigItem.new(key: :root_url,
                                     env_name: "RC_GOOGLE_ROOT_URL",
                                     description: "Root URL for the Google Play API. The provided URL will be used for API calls in place of https://www.googleapis.com/",
                                     optional: true,
                                     verify_block: proc do |value|
                                       UI.user_error!("Could not parse URL '#{value}'") unless value =~ URI.regexp
                                     end),
        ]
      end

      def self.available_options_app_store_connect
        [
          FastlaneCore::ConfigItem.new(key: :apple_username,
                                       env_name: "RC_APPLE_USERNAME",
                                       description: "Your Apple ID Username for App Store Connect"),
          FastlaneCore::ConfigItem.new(key: :apple_team_id,
                                       env_name: "RC_APPLE_TEAM_ID",
                                       description: "The ID of your App Store Connect team if you're in multiple teams",
                                       optional: true,
                                       skip_type_validation: true, # as we also allow integers, which we convert to strings anyway
                                       code_gen_sensitive: true,
                                       verify_block: proc do |value|
                                         ENV["FASTLANE_ITC_TEAM_ID"] = value.to_s
                                       end),
          FastlaneCore::ConfigItem.new(key: :apple_team_name,
                                       env_name: "RC_APPLE_TEAM_NAME",
                                       description: "The name of your App Store Connect team if you're in multiple teams",
                                       optional: true,
                                       code_gen_sensitive: true,
                                       verify_block: proc do |value|
                                         ENV["FASTLANE_ITC_TEAM_NAME"] = value.to_s
                                       end),
          FastlaneCore::ConfigItem.new(key: :apple_app_identifier,
                                       env_name: "RC_APPLE_APP_IDENTIFIER",
                                       description: "The bundle identifier of your app",
                                       optional: false,
                                       code_gen_sensitive: true)
        ]
      end

      def self.available_options_revenuecat
        [
          FastlaneCore::ConfigItem.new(key: :revenuecat_api_key,
                                       env_name: "RC_API_KEY",
                                       description: "The RevenueCat API Key for your Apple app used to filter only IAPs that are used in offerings",
                                       optional: true,
                                       code_gen_sensitive: true),
          FastlaneCore::ConfigItem.new(key: :revenuecat_project_id,
                                       env_name: "RC_PROJECT_ID",
                                       description: "The RevenueCat project id",
                                       optional: true,
                                       code_gen_sensitive: true),
          FastlaneCore::ConfigItem.new(key: :revenuecat_app_id,
                                       env_name: "RC_APP_ID",
                                       description: "The RevenueCat app id to filter by (TEMPORARY)",
                                       optional: true,
                                       code_gen_sensitive: true)
        ]
      end

      def self.get_revenuecat_product_identifiers(api_key:, project_id:, app_id:)
        url = URI("https://api.revenuecat.com/v2/projects/#{project_id}/products")

        http = Net::HTTP.new(url.host, url.port)
        http.use_ssl = true

        request = Net::HTTP::Get.new(url)
        request["Accept"] = 'application/json'
        request["X-Platform"] = 'ios'
        request["Content-Type"] = 'application/json'
        request["Authorization"] = "Bearer #{api_key}"

        response = http.request(request)
        json = JSON.parse(response.read_body)

        products = json["items"].select do |product|
          product["app"] == app_id
        end
        identifiers = products.map { |p| p["store_identifier"] }

        UI.verbose("Found RevenueCat product identifiers: #{identifiers.join(', ')}")

        return products, identifiers
      end

      def self.create_revenuecat_product_identifiers(api_key:, project_id:, app_id: , identifier:)
        body = {
          "store_identifier": identifier,
          "app_id": app_id
        }

        url = URI("https://api.revenuecat.com/v2/projects/#{project_id}/products")

        http = Net::HTTP.new(url.host, url.port)
        http.use_ssl = true

        request = Net::HTTP::Post.new(url)
        request["Accept"] = 'application/json'
        request["X-Platform"] = 'ios'
        request["Content-Type"] = 'application/json'
        request["Authorization"] = "Bearer #{api_key}"

        request.body = body.to_json

        response = http.request(request)
        json = JSON.parse(response.read_body)

        UI.success("Added #{identifier}")
      end

      def self.prompt_product_creations(api_key:, project_id:, app_id: , identifiers:)
        UI.important "Products not on RevenueCat:"
        identifiers.each do |identifier|
          UI.message "\t- #{identifier}"
        end
        
        unless UI.confirm("Do you want to add them all?")
          UI.user_error!("Cancelled operation")
        end

        identifiers.each do |identifier|
          self.create_revenuecat_product_identifiers(
            api_key: api_key,
            project_id: project_id,
            app_id: app_id,
            identifier: identifier
          )
        end
      end

      def self.get_google_subscriptions(access_token:, package_name:)
        url = URI("https://androidpublisher.googleapis.com/androidpublisher/v3/applications/#{package_name}/subscriptions")

        http = Net::HTTP.new(url.host, url.port)
        http.use_ssl = true

        request = Net::HTTP::Get.new(url)
        request["Accept"] = 'application/json'
        request["Content-Type"] = 'application/json'
        request["Authorization"] = "Bearer #{access_token}"

        response = http.request(request)
        json = JSON.parse(response.read_body)

        identifiers = json["subscriptions"].map do |subscription|
          product_id = subscription["productId"]

          base_plans = subscription["basePlans"]
          base_plans.map do |base_plan|
            base_plan_id = base_plan["basePlanId"]

            "#{product_id}:#{base_plan_id}"
          end
        end.flatten(1)

        UI.verbose("Found Google Play subscription identifiers: #{identifiers.join(', ')}")
        return identifiers
      end

      def self.get_google_in_app_products(access_token:, package_name:)
        url = URI("https://androidpublisher.googleapis.com/androidpublisher/v3/applications/#{package_name}/inappproducts")

        http = Net::HTTP.new(url.host, url.port)
        http.use_ssl = true

        request = Net::HTTP::Get.new(url)
        request["Accept"] = 'application/json'
        request["Content-Type"] = 'application/json'
        request["Authorization"] = "Bearer #{access_token}"

        response = http.request(request)
        json = JSON.parse(response.read_body)

        identifiers = json["inappproduct"].map do |product|
          product["sku"]
        end

        UI.verbose("Found Google Play in-app product identifiers: #{identifiers.join(', ')}")
        return identifiers
      end

    end
  end
end

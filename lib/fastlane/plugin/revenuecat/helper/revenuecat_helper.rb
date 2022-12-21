require 'fastlane_core/ui/ui'

require 'uri'
require 'net/http'
require 'openssl'
require 'json'

module Fastlane
  UI = FastlaneCore::UI unless Fastlane.const_defined?("UI")

  module Helper
    class RevenuecatHelper
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

    end
  end
end

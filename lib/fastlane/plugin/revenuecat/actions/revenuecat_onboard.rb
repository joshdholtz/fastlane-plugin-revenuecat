require 'fastlane/action'
require_relative '../helper/revenuecat_helper'

module Fastlane
  module Actions
    class RevenuecatOnboardAction < Action

      def self.rc_key_name
        "Created By RevenueCat"
      end

      def self.find_rc_key
				api_keys = Spaceship::ConnectAPI::APIKey.all
        rc_key = api_keys.find do |key|
          key.nickname == rc_key_name
        end
      end

      def self.run(params)
				require 'pp'

        rc_email = UI.input("RevenueCat account email?")
        rc_password = UI.password("RevenueCat account password?")

        apple_email = UI.input("Apple ID email?")
				
#        rc_email = params[:revenuecat_email]
#        rc_password = params[:revenuecat_password]

        info = self.run_apple(params, apple_email)
        self.run_revenuecat(params, rc_email, rc_password, info)
      end

      def self.run_revenuecat(params, email, password, info)
        self.rc_login(params, email, password, info)
      end

      def self.rc_login(params, email, password, info)
        require 'rest-client'

				app_name = info[:app_name]
        bundle_id = info[:bundle_id]
				shared_secret = info[:shared_secret]

			  in_apps = info[:in_apps]
        subs = info[:subs]  

				key_id = info[:key_id]
				issuer_id = info[:issuer_id]
				private_key = info[:private_key]

        #
        # Login
        #
        resp = RestClient.post(
          "https://api.revenuecat.com/v1/developers/login",
          { email: email, password: password }.to_json,
          { content_type: :json, accept: :json, "X-Requested-With": "XMLHttpRequest" }
        )
        cookie = resp.headers[:set_cookie].first

        #
        # Create project
        #
        resp = RestClient.post(
          "https://api.revenuecat.com/internal/v1/developers/me/projects",
          { name: app_name }.to_json,
          { content_type: :json, accept: :json, "X-Requested-With": "XMLHttpRequest" , cookie: cookie }
        )
        rc_project = JSON.parse(resp.body)
        rc_project_id = rc_project["id"]

        UI.important "✅ Created RevenueCat project..."

        #
        # Create app
        #
        resp = RestClient.post(
          "https://api.revenuecat.com/internal/v1/developers/me/projects/#{rc_project_id}/apps",
          {
						name: app_name,
            bundle_id: bundle_id,
            shared_secret: shared_secret,
            small_business_program_start_date: nil,
            small_business_program_end_date: nil,
            store_type: "app_store"
					}.to_json,
          { content_type: :json, accept: :json, "X-Requested-With": "XMLHttpRequest" , cookie: cookie }
        )
        rc_app = JSON.parse(resp.body)
        rc_app_id = rc_app["id"]

        UI.important "✅ Created RevenueCat app..."

        #
        # Update app for App Store Connect API Key
        # 
        resp = RestClient.patch(
          "https://api.revenuecat.com/internal/v1/developers/me/projects/#{rc_project_id}/apps/#{rc_app_id}",
          {
            app_store_connect_api_key: private_key,
            app_store_connect_api_key_id: key_id,
            app_store_connect_api_key_issuer: issuer_id
					}.to_json,
          { content_type: :json, accept: :json, "X-Requested-With": "XMLHttpRequest" , cookie: cookie }
        )
        rc_app = JSON.parse(resp.body)

        #
        # Add products
        #
        in_apps.each do |in_app|
          resp = RestClient.post(
            "https://api.revenuecat.com/internal/v1/developers/me/projects/#{rc_project_id}/apps/#{rc_app_id}/products",
            {
              product_type: "subscription",
              identifier: in_app[:id],
              display_name: in_app[:name]
            }.to_json,
            { content_type: :json, accept: :json, "X-Requested-With": "XMLHttpRequest" , cookie: cookie }
          )

          UI.important "➡️  Importing in-app #{in_app[:name]} (#{in_app[:id]})..."
        end 
        subs.each do |sub|
          resp = RestClient.post(
            "https://api.revenuecat.com/internal/v1/developers/me/projects/#{rc_project_id}/apps/#{rc_app_id}/products",
            {
              product_type: "subscription",
              identifier: sub[:id],
              display_name: sub[:name]
            }.to_json,
            { content_type: :json, accept: :json, "X-Requested-With": "XMLHttpRequest" , cookie: cookie }
          )

          UI.important "➡️  Importing sub #{sub[:name]} (#{sub[:id]})..."
        end

        url = "https://app.revenuecat.com/projects/#{rc_project_id}/apps/#{rc_app_id}"

        puts ""
        UI.important "View the RevenueCat app at... #{url}"

        api_key = rc_app["api_key"]["key"]

        code = <<~HELLO
Purchases.configure(
    with: Configuration.Builder(withAPIKey: "#{api_key}")
        .build()
) 
        HELLO

				puts ""
				UI.important "Add this intialization code to your app to quickly get started..."
				puts code

      end

      def self.run_apple(params, email)
        self.auth_apple(params, email)

        app = self.select_app(params)

        in_apps = self.get_app_store_in_app_purchases(app)
        subs = self.get_app_store_subscriptions(app)

        shared_secret = self.get_shared_secret(params, app)
        api_key_info = self.create_api_key(params)

        #
        # Output
        #
        
        puts ""
        puts ""
        
        table = Terminal::Table.new(
          title: "App Store Connect API Key".yellow,
          headings: ['Name', 'ID', 'Issuer ID', 'Private Key'],
          rows: FastlaneCore::PrintTable.transform_output([[
            api_key_info[:nickname],
            api_key_info[:key_id],
            api_key_info[:issuer_id],
            "#{api_key_info[:private_key][0, 10]}...",
          ]])
        )
        puts table

        puts ""

        table = Terminal::Table.new(
          title: "App Specific Shared Secret".yellow,
          #headings: ['Value'],
          rows: FastlaneCore::PrintTable.transform_output([[shared_secret]])
        )
        puts table

        puts ""
        puts ""

        UI.important "✅ Created App Store Connect API Key..."
        UI.important "✅ Found App Specific Shared Secret..."

        return api_key_info.merge({
          shared_secret: shared_secret,
          app_name: app.name,
          bundle_id: app.bundle_id,
          in_apps: in_apps,
          subs: subs
        })
      end

      def self.auth_apple(params, email)
        require 'spaceship'

        UI.message("Login to App Store Connect (#{email || params[:apple_username]})")
        Spaceship::ConnectAPI.login(email || params[:apple_username], use_portal: false, use_tunes: true)
        UI.message("Login successful")
      end

      def self.select_app(params)
        apps = Spaceship::ConnectAPI::App.all

        displayable_apps = apps.map do |app|
          "#{app.name} (#{app.bundle_id})"
        end

        selected = UI.select("Which app do you want to import", displayable_apps)
        selected_index = displayable_apps.index(selected)
        app = apps[selected_index]

        UI.important "Selected: #{app.name} (#{app.bundle_id})"

        return app
      end

      def self.create_api_key(params)
        # Check to make sure key is not found
        rc_key = self.find_rc_key()
        if rc_key && rc_key.revoking_date.nil?
          pp rc_key
          UI.user_error! "We are not going to create a second key"
        end

        # Going to create
        api_key = Spaceship::ConnectAPI::APIKey.create(rc_key_name, ["ADMIN"])

        # Refind because we need content provider
        new_rc_key = self.find_rc_key()
        private_key = new_rc_key.download_private_key!

        return {
          nickname: new_rc_key.nickname,
          key_id: new_rc_key.id,
          issuer_id: new_rc_key.provider.id,
          private_key: private_key
        }
			end

      def self.get_shared_secret(params, app)
        shared_secret = app.shared_secrets().first

        if shared_secret
          UI.verbose "Found existing shared secret..."
        else
          UI.verbose "No shared secret found! Need to create..."
          shared_secret = app.generate_shared_secret()
        end

        return shared_secret.secret
      end

			def self.get_app_store_in_app_purchases(app)
        purchases = app.get_in_app_purchases()
        ids_and_names = purchases.map do |p|
          { id: p.product_id, name: p.name }
        end

				return ids_and_names
      end

      def self.get_app_store_subscriptions(app)
        subscriptions = app.get_subscription_groups()
          .map(&:subscriptions)
          .flatten

        ids_and_names = subscriptions.map do |p|
          { id: p.product_id, name: p.name }
        end

        return ids_and_names
      end

      def self.description
        "Automated RevenueCat onboarding from Apple ID"
      end

      def self.authors
        ["Josh Holtz"]
      end

      def self.details
        "Automated RevenueCat onboarding from Apple ID"
      end

      def self.available_options
        Helper::RevenuecatHelper.available_options_apple_id + Helper::RevenuecatHelper.available_options_revenuecat_login
      end

      def self.is_supported?(platform)
        [:ios, :mac].include?(platform)
      end
    end
  end
end

require 'spaceship'

module Spaceship
  class ConnectAPI
    class App

      def shared_secrets()
        return Spaceship::ConnectAPI.client.tunes_request_client.get(
          "https://appstoreconnect.apple.com/iris/v1/apps/#{self.id}/appSharedSecrets"
        ).all_pages.flat_map(&:to_models)
      end

      def generate_shared_secret()
        body = {
          "data": {
            "type": "appSharedSecrets",
            "relationships": {
              "app": {
                "data": {
                  "type": "apps",
                  "id": self.id
                }
              }
            }
          }
        }

        return Spaceship::ConnectAPI.client.tunes_request_client.post(
          "https://appstoreconnect.apple.com/iris/v1/appSharedSecrets",
          body
        ).to_models.first
      end

		end
	end
end

module Spaceship
  class ConnectAPI
    class AppSharedSecrets
      include Spaceship::ConnectAPI::Model

      attr_accessor :secret
      attr_accessor :last_modified_date

      def self.type
        return "appSharedSecrets"
      end

    end
  end
end

module Spaceship
  class ConnectAPI
    class ContentProvider
      include Spaceship::ConnectAPI::Model

      attr_accessor :auto_renew
      attr_accessor :content_type
      attr_accessor :disable_beta_distribution
      attr_accessor :name
      attr_accessor :organization_id
      attr_accessor :status

      def self.type
        return "contentProviders"
      end
    end
  end
end

module Spaceship
  class ConnectAPI
    class APIKey
      include Spaceship::ConnectAPI::Model

      attr_accessor :nickname
      attr_accessor :last_used
      attr_accessor :revoking_date
      attr_accessor :is_active
      attr_accessor :can_download
      attr_accessor :private_key
      attr_accessor :roles
      attr_accessor :all_apps_visible
      attr_accessor :key_type

      attr_accessor :private_key

      attr_accessor :visible_apps
      attr_accessor :provider

      attr_mapping({
        "nickname" => "nickname",
        "lastUsed" => "last_used",
        "revokingDate" => "revoking_date",
        "isActive" => "is_active",
        "canDownload" => "can_download",
        "privateKey" => "private_key",
        "roles" => "roles",
        "allAppsVisible" => "all_apps_visible",
        "keyType" => "key_type",

        "visibleApps" => "visible_apps",
        "provider" => "provider"
      })

      ESSENTIAL_INCLUDES = [
        "visibleApps",
        "provider"
      ].join(",")

      def self.type
        return "apiKeys"
      end

      #
      # API
      #

      def self.all(filter: {}, includes: ESSENTIAL_INCLUDES, limit: nil, sort: nil)
        return Spaceship::ConnectAPI.client.tunes_request_client.get(
          "https://appstoreconnect.apple.com/iris/v1/apiKeys?include=createdBy,revokedBy,provider&sort=-isActive,-revokingDate&limit=500"
        ).all_pages.flat_map(&:to_models)
      end

      def self.create(nickname, roles)
        body = {
          "data": {
            "type": "apiKeys",
            "attributes": {
              "nickname": nickname,
              "roles": roles,
              "allAppsVisible": true,
              "keyType": "PUBLIC_API"
            }
          }
        }

        return Spaceship::ConnectAPI.client.tunes_request_client.post(
          "https://appstoreconnect.apple.com/iris/v1/apiKeys",
          body
        ).to_models.first
      end

      def download_private_key!
        return Spaceship::ConnectAPI.client.tunes_request_client.get(
          "https://appstoreconnect.apple.com/iris/v1/apiKeys/#{id}?fields[apiKeys]=privateKey"
        ).to_models.first.private_key
      end
    end
  end
end


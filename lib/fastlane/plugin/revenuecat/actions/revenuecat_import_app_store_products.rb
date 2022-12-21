require 'fastlane/action'
require_relative '../helper/revenuecat_helper'

module Fastlane
  module Actions
    class RevenuecatImportAppStoreProductsAction < Action
      def self.run(params)
				require 'pp'
        require 'spaceship'

        # Team selection passed though FASTLANE_ITC_TEAM_ID and FASTLANE_ITC_TEAM_NAME environment variables
        # Prompts select team if multiple teams and none specified
        UI.message("Login to App Store Connect (#{params[:apple_username]})")
        Spaceship::ConnectAPI.login(params[:apple_username], use_portal: false, use_tunes: true)
        UI.message("Login successful")

        app_identifier = params[:apple_app_identifier]
        api_key = params[:revenuecat_api_key]
        project_id = params[:revenuecat_project_id]
        app_id = params[:revenuecat_app_id]

        # Get RevenueCat products
        rc_products, rc_product_ids = Helper::RevenuecatHelper.get_revenuecat_product_identifiers(
          api_key: api_key,
          project_id: project_id,
          app_id: app_id
        )

        # Get App Store in-app purchases and subscriptions
        asc_iap_products, asc_iap_product_ids = self.get_app_store_in_app_purchases(app_identifier: app_identifier)
        asc_sub_products, asc_sub_product_ids = self.get_app_store_subscriptions(app_identifier: app_identifier)

        # Find product identifiers that aren't in RevenueCat
        all_asc_product_ids = asc_iap_product_ids + asc_sub_product_ids
        missing_product_ids = all_asc_product_ids - rc_product_ids

        # Create those products in RevenueCat if needed
        if missing_product_ids.empty?
          UI.success("No new products to import into RevenueCat 💪")
        else
          Helper::RevenuecatHelper.prompt_product_creations(
            api_key: api_key,
            project_id: project_id,
            app_id: app_id,
            identifiers: missing_product_ids
          )
        end

				nil
			end

			def self.get_app_store_in_app_purchases(app_identifier:)
				app = Spaceship::ConnectAPI::App.find(app_identifier)

        purchases = app.get_in_app_purchases()
        identifiers = purchases.map.map(&:product_id)

        UI.verbose("Found App Store in-app purchase product identifiers: #{identifiers.join(', ')}")
				return purchases, identifiers
      end

      def self.get_app_store_subscriptions(app_identifier:)
				app = Spaceship::ConnectAPI::App.find(app_identifier)
		
        subscriptions = app.get_subscription_groups()
          .map(&:subscriptions)
          .flatten

        identifiers = subscriptions.map(&:product_id)

        UI.verbose("Found App Store subscription product identifiers: #{identifiers.join(', ')}")
				return subscriptions, identifiers
      end

      def self.description
        "Import missing App Store Connect in-app purchases and subscriptions into RevenueCat"
      end

      def self.authors
        ["Josh Holtz"]
      end

      def self.details
        "Import missing App Store Connect in-app purchases and subscriptions into RevenueCat"
      end

      def self.available_options
        [
          Helper::RevenuecatHelper.available_options_app_store_connect,
          Helper::RevenuecatHelper.available_options_revenuecat
        ].flatten
      end

      def self.is_supported?(platform)
        [:ios, :mac].include?(platform)
      end
    end
  end
end
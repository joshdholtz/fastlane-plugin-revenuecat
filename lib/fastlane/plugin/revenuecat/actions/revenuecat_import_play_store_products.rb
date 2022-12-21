require 'fastlane/action'
require_relative '../helper/revenuecat_helper'

module Fastlane
  module Actions
    class RevenuecatImportPlayStoreProductsAction < Action
      def self.run(params)
				require 'pp'
        require 'supply'

        api_key = params[:revenuecat_api_key]
        project_id = params[:revenuecat_project_id]
        app_id = params[:revenuecat_app_id]

        begin
          client = Supply::Client.make_from_config(params: params)
          access_token = client.client.request_options.authorization.access_token
          UI.success("Successfully established connection to Google Play Store.")
          UI.verbose("client: " + client.inspect)
        rescue => e
          UI.error("#{e.message}\n#{e.backtrace.join("\n")}") if FastlaneCore::Globals.verbose?
          UI.error!("Could not establish a connection to Google Play Store with this json key file.")
        end

        # Get Google Play subscription and in-app product identifiers
        play_sub_ids = Helper::RevenuecatHelper.get_google_subscriptions(
          access_token: access_token,
          package_name: "com.joshholtz.whatsmyageagain"
        )
        play_inapp_ids = Helper::RevenuecatHelper.get_google_in_app_products(
          access_token: access_token,
          package_name: "com.joshholtz.whatsmyageagain"
        )

        # Get RevenueCat products
        rc_products, rc_product_ids = Helper::RevenuecatHelper.get_revenuecat_product_identifiers(
          api_key: api_key,
          project_id: project_id,
          app_id: app_id
        )

        # Find product identifiers that aren't in RevenueCat
        all_play_product_ids = play_sub_ids + play_inapp_ids
        missing_product_ids = all_play_product_ids - rc_product_ids

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

      def self.description
        "Import missing Google Play Store in-app purchases and subscriptions into RevenueCat"
      end

      def self.authors
        ["Josh Holtz"]
      end

      def self.details
        "Import missing Google Play Store in-app purchases and subscriptions into RevenueCat"
      end

      def self.available_options
        [
          Helper::RevenuecatHelper.available_options_google_play,
          Helper::RevenuecatHelper.available_options_revenuecat
        ].flatten
      end

      def self.is_supported?(platform)
        [:ios, :mac].include?(platform)
      end
    end
  end
end
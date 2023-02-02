require 'fastlane/action'
require_relative '../helper/revenuecat_helper'

# product_id,country,price,currency,introductory_price,date,duration,introductory_price_duration
# premium_weekly,US,4.99,USD,0.99,2021-09-13,P1W,P2M
# premium_weekly,PA,3.99,USD,0.99,2021-01-01,P1W,P2M
# premium_weekly,CA,8.99,CAD,1.99,2021-01-01,P1W,P2M

module Fastlane
  module Actions
    class RevenuecatCreateAppStorePriceMappingAction < Action
      def self.run(params)
				require 'pp'
        require 'spaceship'
        require 'csv'
        require 'iso_country_codes'

        # Team selection passed though FASTLANE_ITC_TEAM_ID and FASTLANE_ITC_TEAM_NAME environment variables
        # Prompts select team if multiple teams and none specified
        UI.message("Login to App Store Connect (#{params[:apple_username]})")
        Spaceship::ConnectAPI.login(params[:apple_username], use_portal: false, use_tunes: true)
        UI.message("Login successful")

        # Get App Store in-app purchases and subscriptions
        csv_content = self.get_subscriptions_csv_content(params)

        path = File.absolute_path("app_store_price_mapping.csv")
        CSV.open(path, "w") do |csv|
          csv << ["product_id", "country", "price", "currency", "introductory_price", "date", "duration", "introductory_price_duration"]
          csv_content.each do |content|
            csv << content
          end
        end

        UI.success("Mapping file created at: #{path}")

				nil
			end

			def self.get_subscriptions_csv_content(params)
				app = Spaceship::ConnectAPI::App.find(params[:apple_app_identifier])

        subscriptions = app.get_subscription_groups()
          .map(&:subscriptions)
          .flatten

        csv_content = subscriptions.map do |subscription|
          intro_offers_by_territory = {}
          subscription.get_introductory_offers.each do |intro_offer|
            # UI.message(intro_offer.inspect)
            # UI.message(intro_offer.territory.id)
            intro_offers_by_territory[intro_offer.territory.id] = intro_offer
          end

          subscription.get_prices.map do |price|
            duration = ''

            intro_offer_price = ""
            if intro_offers_by_territory[price.territory.id] != nil
              intro_offer = intro_offers_by_territory[price.territory.id]
              if intro_offer.offer_mode == "FREE_TRIAL"
                # Free trials don't include a price in the ASC API response, so we need to add it manually
                intro_offer_price = "0.00"
              end
            end

            UI.message(price.start_date)

            [
              subscription.product_id,
              convert_three_to_two_char_country_codes(price.territory.id),
              price.subscription_price_point.customer_price,
              price.territory.currency,
              intro_offer_price,
              price.start_date,
              map_duration(subscription.subscription_period),
              map_duration(intro_offers_by_territory[price.territory.id]&.duration)
            ]
          end
        end.flatten(1)

        csv_content
      end

      def self.map_duration(duration)
        case duration
        when "ONE_DAY"
          "P1D"
        when "THREE_DAYS"
          "P3D"
        when "ONE_WEEK"
          "P1W"
        when "TWO_WEEKS"
          "P2W"
        when "ONE_MONTH"
          "P1M"
        when "TWO_MONTHS"
          "P2M"
        when "THREE_MONTHS"
          "P3M"
        when "SIX_MONTHS"
          "P6M"
        when "ONE_YEAR"
          "P1Y"
        else
          nil
        end
      end

      def self.convert_three_to_two_char_country_codes(three_char_country_code)

        # As of Feb 1, 2023, Kosovo is not listed as an ISO standard country. 
        # The unofficial 2 and 3-digit codes are used by the European Commission and others until 
        # Kosovo is assigned an ISO code. In the meantime, Apple seems to use "XKS" and "XK".
        if three_char_country_code == "XKS" || three_char_country_code == "XKX" || three_char_country_code == "XXK"
          return "XK"
        end
        
        begin
          code = IsoCountryCodes.find(three_char_country_code)
          return code.alpha2
        rescue => error
          UI.error("Cannot convert unknown country code #{three_char_country_code} from three characters to two characters.")
          UI.crash!(error)
        end
      end

      def self.description
        "Create price mapping CSV needed for a RevenueCat import migration"
      end

      def self.authors
        ["Josh Holtz", "Will Taylor"]
      end

      def self.details
        "Create price mapping CSV needed for a RevenueCat import migration"
      end

      def self.available_options
        Helper::RevenuecatHelper.available_options_app_store_connect
      end

      def self.is_supported?(platform)
        [:ios, :mac].include?(platform)
      end
    end
  end
end
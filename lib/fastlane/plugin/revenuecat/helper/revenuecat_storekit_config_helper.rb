module Fastlane
  module Helper
    class RevenuecatHelper
      
      def self.demo_storekit_config_file_content
        content = <<-CONTENT
{
  "identifier" : "E36A6C53",
  "nonRenewingSubscriptions" : [

  ],
  "products" : [
    {
      "displayPrice" : "0.99",
      "familyShareable" : false,
      "internalID" : "9B90D777",
      "localizations" : [
        {
          "description" : "Premium Lifetime",
          "displayName" : "Premium Lifetime",
          "locale" : "en_US"
        }
      ],
      "productID" : "demo_rc_premium_lifetime",
      "referenceName" : "Premium LIfetime",
      "type" : "NonConsumable"
    }
  ],
  "settings" : {

  },
  "subscriptionGroups" : [
    {
      "id" : "3F96AC84",
      "localizations" : [

      ],
      "name" : "premium",
      "subscriptions" : [
        {
          "adHocOffers" : [

          ],
          "codeOffers" : [

          ],
          "displayPrice" : "2.99",
          "familyShareable" : false,
          "groupNumber" : 1,
          "internalID" : "D7BBA925",
          "introductoryOffer" : null,
          "localizations" : [
            {
              "description" : "Premium Monthly",
              "displayName" : "Premium Monthly",
              "locale" : "en_US"
            }
          ],
          "productID" : "demo_rc_premium_monthly",
          "recurringSubscriptionPeriod" : "P1M",
          "referenceName" : "Premium Monthly",
          "subscriptionGroupID" : "3F96AC84",
          "type" : "RecurringSubscription"
        },
        {
          "adHocOffers" : [

          ],
          "codeOffers" : [

          ],
          "displayPrice" : "12.99",
          "familyShareable" : false,
          "groupNumber" : 1,
          "internalID" : "2D2C26F8",
          "introductoryOffer" : null,
          "localizations" : [
            {
              "description" : "Premium Yearly",
              "displayName" : "Premium Yearly",
              "locale" : "en_US"
            }
          ],
          "productID" : "demo_rc_premium_yearly",
          "recurringSubscriptionPeriod" : "P1Y",
          "referenceName" : "Premium Yearly",
          "subscriptionGroupID" : "3F96AC84",
          "type" : "RecurringSubscription"
        }
      ]
    }
  ],
  "version" : {
    "major" : 2,
    "minor" : 0
  }
}
        CONTENT

        content
      end

    end
  end
end

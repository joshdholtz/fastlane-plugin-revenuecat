require 'xcodeproj'
require 'fastlane_core/project'

module Fastlane
  module Actions
    class RevenueCatSetupDemoProductsAction < Action
      def self.run(params)
        api_key = params[:revenuecat_api_key]
        project_id = params[:revenuecat_project_id]
        app_id = params[:revenuecat_app_id]

        require 'pp'

        add_sk_config

        products = configure_rc_products(api_key, project_id, app_id)
        configure_rc_offering(api_key, project_id, app_id, products)
      end

      def self.configure_rc_offering(api_key, project_id, app_id, products)
        # Create offering
        offering = Helper::RevenuecatHelper.create_revenuecat_offering(
          api_key: api_key,
          project_id: project_id,
          app_id: app_id,
          lookup_key: "demo_rc",
          display_name: "Demo RC"
        )
        offering_id = offering["id"]

        # Create package
        package_monthly = Helper::RevenuecatHelper.create_revenuecat_package(
          api_key: api_key,
          project_id: project_id,
          app_id: app_id,
          offering_id: offering_id,
          lookup_key: "$rc_monthly",
          display_name: "Monthly",
          position: 1
        )
        package_yearly = Helper::RevenuecatHelper.create_revenuecat_package(
          api_key: api_key,
          project_id: project_id,
          app_id: app_id,
          offering_id: offering_id,
          lookup_key: "$rc_annual",
          display_name: "Yearly",
          position: 2
        )
        package_lifetime = Helper::RevenuecatHelper.create_revenuecat_package(
          api_key: api_key,
          project_id: project_id,
          app_id: app_id,
          offering_id: offering_id,
          lookup_key: "lifetime",
          display_name: "Lifetime",
          position: 3
        )

        # Attach products to package
        monthly_product_id = products.detect { |p| p["store_identifier"] == "demo_rc_premium_monthly"}["id"]
        yearly_product_id = products.detect { |p| p["store_identifier"] == "demo_rc_premium_yearly"}["id"]
        lifetime_product_id = products.detect { |p| p["store_identifier"] == "demo_rc_premium_lifetime"}["id"]

        Helper::RevenuecatHelper.attach_products_to_package(
          api_key: api_key,
          project_id: project_id,
          app_id: app_id,
          product_ids: [monthly_product_id],
          package_id: package_monthly["id"]
        )
        Helper::RevenuecatHelper.attach_products_to_package(
          api_key: api_key,
          project_id: project_id,
          app_id: app_id,
          product_ids: [yearly_product_id],
          package_id: package_yearly["id"]
        )
        Helper::RevenuecatHelper.attach_products_to_package(
          api_key: api_key,
          project_id: project_id,
          app_id: app_id,
          product_ids: [lifetime_product_id],
          package_id: package_lifetime["id"]
        )

      end

      def self.configure_rc_products(api_key, project_id, app_id)
        # Create products
        identifiers = ["demo_rc_premium_lifetime", "demo_rc_premium_monthly", "demo_rc_premium_yearly"]
        identifiers.each do |identifier|
          Helper::RevenuecatHelper.create_revenuecat_product_identifiers(
            api_key: api_key,
            project_id: project_id,
            app_id: app_id,
            identifier: identifier
          )
        end

        # Create entitlements
        entitlements = {"demo_rc_premium": "Demo RC Premium"}
        entitlements.each do |lookup_key, display_name|
          Helper::RevenuecatHelper.create_revenuecat_entitlement(
            api_key: api_key,
            project_id: project_id,
            app_id: app_id,
            lookup_key: lookup_key,
            display_name: display_name
          )
        end

        # Get products and entitlement for attaching
        rc_products, trash = Helper::RevenuecatHelper.get_revenuecat_product_identifiers(
          api_key: api_key,
          project_id: project_id,
          app_id: app_id
        )
        rc_entitlements = Helper::RevenuecatHelper.get_revenuecat_entitlements(
          api_key: api_key,
          project_id: project_id,
          app_id: app_id
        )

        products = rc_products
          .select do |h|
            identifiers.include?(h["store_identifier"])
          end
        product_ids = products.map { |h| h["id"]}
        ent_id = rc_entitlements
          .select do |h|
            entitlements.keys.map(&:to_s).include?(h["lookup_key"])
          end
          .map { |h| h["id"]}
          .first

        Helper::RevenuecatHelper.attach_products_to_entitlement(
          api_key: api_key,
          project_id: project_id,
          app_id: app_id,
          product_ids: product_ids,
          entitlement_id: ent_id
        )

        return products
      end

      def self.add_sk_config()
        storekit_config_file_content = Helper::RevenuecatHelper.demo_storekit_config_file_content

        config = {}
        FastlaneCore::Project.detect_projects(config)

        project_path = config[:project]

        sk_config_path = File.join("RevenueCatDemoStoreKitConfig.storekit")
        File.write(sk_config_path, storekit_config_file_content)

        project = Xcodeproj::Project.open(project_path)
        project.new_file(sk_config_path)
        project.save

        scheme_dir = File.join(project.path, "xcshareddata", "xcschemes")
        schemes = Xcodeproj::Project.schemes(project.path)
        schemes.each do |scheme_name|
          scheme_path = File.join(scheme_dir, "#{scheme_name}.xcscheme")
          scheme = Xcodeproj::XCScheme.new(scheme_path)

          sk_config = REXML::Element.new('StoreKitConfigurationFileReference')
          sk_config.attributes['identifier'] = '../../RevenueCatDemoStoreKitConfig.storekit'
          scheme.launch_action.xml_element.add_element(sk_config)

          scheme.save_as(project.path, "#{scheme_name} (RevenueCat Demo)")
        end
      end

      #####################################################
      # @!group Documentation
      #####################################################

      def self.description
        "Auto configures Xcode project and RevenueCat project to make take it to ah-ha moment faster"
      end

      def self.details
        "Auto configures and adds a StoreKit Config file and RevenueCat project with demo products, offerings, and entitlements to make quick testing easier"
      end

      def self.available_options
        [
          Helper::RevenuecatHelper.available_options_revenuecat
        ].flatten
      end


      def self.authors
        ["joshdholtz"]
      end

      def self.is_supported?(platform)
        [:ios, :mac].include?(platform)
      end
    end
  end
end

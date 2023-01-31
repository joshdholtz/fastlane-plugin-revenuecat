# RevenueCat plugin

[![fastlane Plugin Badge](https://rawcdn.githack.com/fastlane/fastlane/master/fastlane/assets/plugin-badge.svg)](https://rubygems.org/gems/fastlane-plugin-revenuecat)

## Getting Started

This project is a [_fastlane_](https://github.com/fastlane/fastlane) plugin. To get started with `fastlane-plugin-revenuecat`, add it to your project by running:

```bash
fastlane add_plugin revenuecat
```

If Fastlane cannot find the plugin, try specifying the branch in your `Pluginfile`:
```plaintext
gem 'fastlane-plugin-revenuecat', git: 'https://github.com/RevenueCat/fastlane-plugin-revenuecat', branch: 'main'
```

## About RevenueCat

⚠️ Some of these actions requires access to RevenueCat's V2 Developer API

| Action | Uses V2 Developer AI | Description |
| --- | --- | --- |
| revenuecat_import_app_store_products | Yes | Imports products on App Store Connect that are not in RevenueCat yet |
| revenuecat_import_play_store_products | Yes | Imports products on Google Play Consoles that are not in RevenueCat yet |
| revenuecat_create_app_store_price_mapping | No | Creates a [price mapping CSV](https://github.com/RevenueCat-Samples/import-csv-samples/blob/main/iOS/ios_product_price_map_sample.csv) need for [bulk imports](https://www.revenuecat.com/docs/receipt-imports#bulk-imports) for migrations |

### Action `import_app_store`

Imports products on App Store Connect that are not in RevenueCat yet

```ruby
lane :import_app_store do
  revenuecat_import_app_store_products(
    apple_username: "you@example.com",
    apple_team_name: "Your Team",
    apple_app_identifier: "com.example.app",

    revenuecat_api_key: "sk_xxxxxxxxxxxx",
    revenuecat_project_id: "projXXXXXX",
    revenuecat_app_id: "appXXXXX"
  )
end
```

The output will look something like the following:

```sh
$: fastlane import_app_store
[22:59:59]: Login to App Store Connect (you@example.com)
[23:00:05]: Login successful
[23:00:09]: Products not on RevenueCat:
[23:00:09]:     - com.joshholtz.WhatsMyAgeAgain.superTip
[23:00:09]:     - tipscription.small
[23:00:09]: Do you want to add them all? (y/n)
y
[23:00:12]: Added com.joshholtz.WhatsMyAgeAgain.superTip
[23:00:12]: Added tipscription.small
```

### Action `import_play_store`

Imports products on Google Play Consoles that are not in RevenueCat yet 

```ruby
lane :import_play_store do
  revenuecat_import_play_store_products(
    json_key: "./fastlane/service-credentials.json",

    revenuecat_api_key: "sk_xxxxxxxxxxxx",
    revenuecat_project_id: "projXXXXXX",
    revenuecat_app_id: "appXXXXX"
  )
end
```

The output will look something like the following:

```sh
$: fastlane import_play_store
[22:57:59]: Successfully established connection to Google Play Store.
[22:58:00]: Products not on RevenueCat:
[22:58:00]:     - tipscription_small:monthly
[22:58:00]:     - single_tip_small
[22:58:00]: Do you want to add them all? (y/n)
y
[22:58:01]: Added tipscription_small:monthly
[22:58:02]: Added single_tip_small
```

### Action `revenuecat_create_app_store_price_mapping`

Creates a [price mapping CSV](https://github.com/RevenueCat-Samples/import-csv-samples/blob/main/iOS/ios_product_price_map_sample.csv) need for [bulk imports](https://www.revenuecat.com/docs/receipt-imports#bulk-imports) for migrations

```ruby
lane :price_mapping_app_store do
  revenuecat_create_app_store_price_mapping(
    apple_username: "you@example.com",
    apple_team_name: "Your Team",
    apple_app_identifier: "com.example.app"
  )
end
```

The output will look something like the following:

```sh
$: fastlane price_mapping_app_store
[22:58:39]: Login to App Store Connect (you@example.com)
[22:58:43]: Login successful
[22:58:59]: Mapping file creatd at: app_store_price_mapping.csv
```

The exported CSV will look something like the following:

```csv
product_id,country,price,currency,introductory_price,date,duration,introductory_price_duration
tipscription.small,ARE,12.99,AED,2.99,2021-02-04,P1M,P2M
tipscription.small,AFG,2.99,USD,0.99,2021-02-04,P1M,P2M
tipscription.small,ATG,2.99,USD,0.99,2021-02-04,P1M,P2M
tipscription.small,AIA,2.99,USD,0.99,2021-02-04,P1M,P2M
tipscription.small,ALB,3.99,USD,0.99,2021-02-04,P1M,P2M
tipscription.small,ARM,3.99,USD,0.99,2021-02-04,P1M,P2M
```

## Example

Check out the [example `Fastfile`](fastlane/Fastfile) to see how to use this plugin. Try it by cloning the repo, running `fastlane install_plugins` and `bundle exec fastlane test`.


## Run tests for this plugin

To run both the tests, and code style validation, run

```
rake
```

To automatically fix many of the styling issues, use
```
rubocop -a
```

## Issues and Feedback

For any other issues and feedback about this plugin, please submit it to this repository.

## Troubleshooting

If you have trouble using plugins, check out the [Plugins Troubleshooting](https://docs.fastlane.tools/plugins/plugins-troubleshooting/) guide.

## Using _fastlane_ Plugins

For more information about how the `fastlane` plugin system works, check out the [Plugins documentation](https://docs.fastlane.tools/plugins/create-plugin/).

## About _fastlane_

_fastlane_ is the easiest way to automate beta deployments and releases for your iOS and Android apps. To learn more, check out [fastlane.tools](https://fastlane.tools).

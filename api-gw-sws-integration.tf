# Infrastructure for Yandex Smart Web Security and Yandex API Gateway
#
# RU: https://yandex.cloud/ru/docs/tutorials/serverless/api-gw-sws-integration
# EN: https://yandex.cloud/en/docs/tutorials/serverless/api-gw-sws-integration
#
# Configure the parameters of the Smart Web Security profiles and API gateway:

locals {
  # The following settings are to be specified by the user. Change them as you wish.

  # Settings for the ARL profile
  arl_name  = "" # Name of the ARL profile
  folder_id = "" # ID of the folder for the ARL profile

  # Settings for the Smart Web Security profile
  sws_name    = ""     # Name of the Smart Web Security profile
  allowed_ips = ["", ""] # List of the allowed IP addresses

  # Settings for the API gateway
  api-gw-name = "" # Name of the API gateway

  # This setting enables creation of the API gateway. Change it only after ARL and SWS profiles have been created.
  create-api-gw = 0 # Set this setting to 1 to enable creation of the API gateway
}

resource "yandex_sws_advanced_rate_limiter_profile" "my-arl-profile" {
  description = "ARL profile which sets requests limit and groups requests by query param"
  name        = local.arl_name
  folder_id   = local.folder_id

  advanced_rate_limiter_rule {
    description = "Rule that sets requests limit and groups requests by query param"
    name        = "my-arl-rule"
    priority    = 999900

    dynamic_quota {
      action = "DENY"
      limit  = 1
      period = 60
      characteristic {
        key_characteristic {
          type  = "QUERY_KEY"
          value = "token"
        }
      }
    }
  }
}

resource "yandex_sws_security_profile" "my-sws-profile" {
  description                      = "Smart Web Security profile which includes ARL profile and sets IP filter"
  name                             = local.sws_name
  default_action                   = "ALLOW"
  advanced_rate_limiter_profile_id = yandex_sws_advanced_rate_limiter_profile.my-arl-profile.id
  security_rule {
    name     = "smart-protection-rule"
    priority = 999900
    smart_protection {
      mode = "API"
    }
  }
  security_rule {
    name     = "ip-filter-rule"
    priority = 999700
    rule_condition {
      action = "ALLOW"
      condition {
        source_ip {
          ip_ranges_match {
            ip_ranges = local.allowed_ips
          }
        }
      }
    }
  }
}

resource "yandex_api_gateway" "test-api-gateways" {
  description = "API gateway with Smart Web Security profile"
  name        = local.api-gw-name
  count       = local.create-api-gw
  spec        = <<-EOT
    openapi: "3.0.0"
    x-yc-apigateway:
      smartWebSecurity:
        securityProfileId: <идентификатор_профиля_Smart_Web_Security>
    info:
      version: 1.0.0
      title: Protected application
      license:
        name: MIT
    paths:
      /:
        get:
          x-yc-apigateway-integration:
            type: dummy
            content:
              '*': "This application is protected by SWS!"
            http_code: 200
  EOT
}

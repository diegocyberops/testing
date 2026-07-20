resource "google_compute_security_policy" "edge_armor_policy" {
  name        = "edge-armor-policy"
  description = "Allowlist deny-by-default para la API pública de Nimbo Pay"

  # Health Check
  rule {
    action   = "allow"
    priority = 100
    preview  = true

    match {
      expr {
        expression = "request.path.matches('^/api/v1/status$')"
      }
    }

    description = "Allow health endpoint"
  }

  # API Merchants
  rule {
    action   = "allow"
    priority = 110
    preview  = true

    match {
      expr {
        expression = "request.path.matches('^/api/v1/merchants(?:/|$)')"
      }
    }

    description = "Allow merchants API"
  }

  # Orders
  rule {
    action   = "allow"
    priority = 120
    preview  = true

    match {
      expr {
        expression = "request.path.matches('^/api/v1/orders(?:/|$)')"
      }
    }

    description = "Allow orders API"
  }

  # Incoming Webhooks
  rule {
    action   = "allow"
    priority = 130
    preview  = true

    match {
      expr {
        expression = "request.path.startsWith('/hooks/')"
      }
    }

    description = "Allow trusted webhooks"
  }

  # Public Catalog
  rule {
    action   = "allow"
    priority = 140
    preview  = true

    match {
      expr {
        expression = "request.path.matches('^/api/v1/catalog/[^/]+(?:/items)?$')"
      }
    }

    description = "Allow public catalog"
  }

  # Public Documentation
  rule {
    action   = "allow"
    priority = 150
    preview  = true

    match {
      expr {
        expression = "request.path.matches('^/api/v1/docs(?:/|$)')"
      }
    }

    description = "Allow API documentation"
  }

  # Rate Limiting Login
  rule {
    action   = "rate_based_ban"
    priority = 300
    preview  = true

    match {
      expr {
        expression = "request.path.matches('^/api/v1/sessions$')"
      }
    }

    rate_limit_options {

      conform_action = "allow"
      exceed_action  = "deny(429)"

      rate_limit_threshold {
        count        = 50
        interval_sec = 60
      }

      ban_duration_sec = 600
      enforce_on_key   = "IP"
    }

    description = "Protect login endpoint against brute force"
  }

  # Explicit Deny
  rule {
    action   = "deny(403)"
    priority = 2000
    preview  = false

    match {
      expr {
        expression = "request.path.matches('.*')"
      }
    }

    description = "Deny all requests not explicitly allowed"
  }

  # Default Rule
  rule {
    action   = "deny(403)"
    priority = 2147483647

    match {
      versioned_expr = "SRC_IPS_V1"

      config {
        src_ip_ranges = ["*"]
      }
    }

    description = "Default deny rule"
  }
}
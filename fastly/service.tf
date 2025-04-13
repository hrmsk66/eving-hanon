resource "fastly_service_vcl" "service" {
  default_ttl        = 3600
  http3              = false
  name               = "hanon"
  stale_if_error     = false
  stale_if_error_ttl = 43200

  backend {
    address               = "127.0.0.1"
    auto_loadbalance      = false
    between_bytes_timeout = 10000
    connect_timeout       = 1000
    error_threshold       = 0
    first_byte_timeout    = 15000
    keepalive_time        = 0
    max_conn              = 200
    name                  = "Host 1"
    port                  = 443
    shield                = "sjc-ca-us"
    ssl_check_cert        = false
    use_ssl               = true
    weight                = 100
  }
  backend {
    address               = "127.0.0.1"
    auto_loadbalance      = false
    between_bytes_timeout = 10000
    connect_timeout       = 1000
    error_threshold       = 0
    first_byte_timeout    = 15000
    keepalive_time        = 0
    max_conn              = 200
    name                  = "Host 2"
    port                  = 443
    shield                = "iad-va-us"
    ssl_check_cert        = false
    use_ssl               = true
    weight                = 100
  }
  backend {
    address               = "127.0.0.1"
    auto_loadbalance      = false
    between_bytes_timeout = 10000
    connect_timeout       = 1000
    error_threshold       = 0
    first_byte_timeout    = 15000
    keepalive_time        = 0
    max_conn              = 200
    name                  = "Host 3"
    port                  = 443
    shield                = "frankfurt-de"
    ssl_check_cert        = false
    use_ssl               = true
    weight                = 100
  }

  dictionary {
    force_destroy = false
    name          = "otfp"
    write_only    = true
  }

  domain {
    name = "hanon.global.ssl.fastly.net"
  }

  vcl {
    content = file("vcl/service/main.vcl")
    main    = true
    name    = "main"
  }
  comment = ""
}

output "fastly_service_url" {
  value = "https://cfg.fastly.com/${fastly_service_vcl.service.id}"
}

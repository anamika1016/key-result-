# config/environments/production.rb
Rails.application.configure do
  # -----------------------------
  # Code loading
  # -----------------------------
  config.enable_reloading = false
  config.eager_load = true

  # -----------------------------
  # Error reports
  # -----------------------------
  config.consider_all_requests_local = false

  # -----------------------------
  # Caching
  # -----------------------------
  config.action_controller.perform_caching = true
  config.cache_store = :solid_cache_store
  config.public_file_server.headers = {
    "Cache-Control" => "public, max-age=#{1.year.to_i}"
  }

  # -----------------------------
  # Active Storage
  # -----------------------------
  config.active_storage.service = :local

  # -----------------------------
  # SSL / HTTPS (disabled)
  # -----------------------------
  config.force_ssl = false
  config.assume_ssl = false
  config.action_controller.forgery_protection_origin_check = false

  # -----------------------------
  # Logging
  # -----------------------------
  config.log_tags = [:request_id]
  config.logger = ActiveSupport::TaggedLogging.logger(STDOUT)
  config.log_level = ENV.fetch("RAILS_LOG_LEVEL", "info")

  # -----------------------------
  # Health check
  # -----------------------------
  config.silence_healthcheck_path = "/up"

  # -----------------------------
  # Active Job
  # -----------------------------
  config.active_job.queue_adapter = :solid_queue
  config.solid_queue.connects_to = { database: { writing: :queue } }

  # -----------------------------
  # I18n
  # -----------------------------
  config.i18n.fallbacks = true

  # -----------------------------
  # Action Mailer
  # -----------------------------
  config.action_mailer.delivery_method = :smtp
  config.action_mailer.default_url_options = {
    host: "kra.asaindia.org",
    protocol: "http"
  }
  config.action_mailer.smtp_settings = {
    address: "smtp.ploughmanagro.com",
    port: 587,
    domain: "kra.asaindia.org",
    user_name: "notification@ploughmanagro.com",
    password: ENV["SMTP_PASSWORD"],
    authentication: :plain,
    enable_starttls_auto: true
  }
  config.action_mailer.perform_deliveries = true
  config.action_mailer.raise_delivery_errors = true

  # -----------------------------
  # Host Security
  # -----------------------------
  config.hosts << "kra.asaindia.org"
  config.hosts << "139.59.45.69"

  # -----------------------------
  # Active Record
  # -----------------------------
  config.active_record.dump_schema_after_migration = false
  config.active_record.attributes_for_inspect = [:id]

  # -----------------------------
  # Deprecation Reports
  # -----------------------------
  config.active_support.report_deprecations = false
end
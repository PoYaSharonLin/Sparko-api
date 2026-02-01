# frozen_string_literal: true

require "fileutils"
require_relative "../app/infrastructure/utilities/logger"

require "aws-sdk-core"
require "aws-sdk-sqs"
require "aws-sdk-sts"
require "shoryuken"

ENV["RACK_ENV"] ||= "development"
ENV["PYTHON_BIN"] ||= File.expand_path("../../.venv/bin/python", __dir__)

# Avoid AWS SDK trying IMDS on laptops when creds/env are missing.
ENV["AWS_EC2_METADATA_DISABLED"] ||= "true" if ENV["RACK_ENV"] == "development"

def env_blank?(k)
  ENV[k].nil? || ENV[k].strip.empty?
end

# ----------------------------
# HF cache env
# ----------------------------
cache_root = File.expand_path("../tmp/hf_cache", __dir__)
FileUtils.mkdir_p(cache_root)

ENV["HF_HOME"] = cache_root if env_blank?("HF_HOME")
ENV["TRANSFORMERS_CACHE"] = cache_root if env_blank?("TRANSFORMERS_CACHE")
ENV["HF_HUB_CACHE"] = File.join(cache_root, "hub") if env_blank?("HF_HUB_CACHE")
ENV["SENTENCE_TRANSFORMERS_HOME"] = File.join(cache_root, "sentence_transformers") if env_blank?("SENTENCE_TRANSFORMERS_HOME")
ENV["EMBED_SERVICE_URL"] ||= "http://127.0.0.1:8001/embed"

# ----------------------------
# Logging + AWS diagnostics
# ----------------------------
begin
  logger = Sparko.logger
  logger.info("[BOOT] RACK_ENV=#{ENV['RACK_ENV'].inspect} pid=#{Process.pid}")

  logger.info(
    "[BOOT] SQS config region=#{ENV['AWS_REGION'].inspect} " \
    "queue_name=#{ENV['SQS_QUEUE_NAME'].inspect} queue_url=#{ENV['SQS_QUEUE_URL'].inspect}"
  )

  aws_log_level_str = (ENV["AWS_SDK_LOG_LEVEL"] || "off").downcase
  aws_log_level =
    case aws_log_level_str
    when "debug" then :debug
    when "info"  then :info
    when "warn"  then :warn
    when "error" then :error
    when "fatal" then :fatal
    when "off", "none" then nil
    else nil
    end

  aws_config = {
    region: ENV.fetch("AWS_REGION", "us-east-1"),
    retry_mode: (ENV["AWS_RETRY_MODE"] || "adaptive"),
    max_attempts: Integer(ENV["AWS_MAX_ATTEMPTS"] || "10"),

    # prevent "stuck socket forever" on sleep/wifi/vpn changes
    http_open_timeout: Float(ENV["AWS_HTTP_OPEN_TIMEOUT"] || "2"),
    http_read_timeout: Float(ENV["AWS_HTTP_READ_TIMEOUT"] || "20"),
    http_idle_timeout: Float(ENV["AWS_HTTP_IDLE_TIMEOUT"] || "5")
  }

  if aws_log_level
    aws_config[:logger] = logger
    aws_config[:log_level] = aws_log_level
  end

  Aws.config.update(aws_config)

  logger.info(
    "[BOOT] Aws.config set: retry_mode=#{Aws.config[:retry_mode]} max_attempts=#{Aws.config[:max_attempts]} " \
    "open_timeout=#{Aws.config[:http_open_timeout]} read_timeout=#{Aws.config[:http_read_timeout]} " \
    "idle_timeout=#{Aws.config[:http_idle_timeout]} aws_log_level=#{aws_log_level || :off}"
  )

  begin
    ident = Aws::STS::Client.new.get_caller_identity
    logger.info("[BOOT] AWS identity account=#{ident.account} arn=#{ident.arn}")
  rescue StandardError => e
    logger.warn("[BOOT] AWS identity lookup failed: #{e.class} #{e.message}")
  end
rescue StandardError => e
  warn "[BOOT] AWS config init failed: #{e.class}: #{e.message}"
  warn e.backtrace&.first(10)&.join("\n")
end

# ----------------------------
# Load app environment + code
# ----------------------------
require_relative "environment"

require_relative "../require_app"
require_app

# loads workers (and pulls in app code)
require_relative "../app/workers/embed_research_interest_worker"

Sparko.logger.debug("[SHORYUKEN_BOOT] TRANSFORMERS_CACHE=#{ENV['TRANSFORMERS_CACHE'].inspect}")
Sparko.logger.debug(
  "BOOT python=#{ENV['PYTHON_BIN']} HF_HOME=#{ENV['HF_HOME']} TRANSFORMERS_CACHE=#{ENV['TRANSFORMERS_CACHE']}"
)

# ----------------------------
# Shoryuken logger wiring + heartbeat
# ----------------------------
begin
  logger = Sparko.logger

  Shoryuken.logger = logger if Shoryuken.respond_to?(:logger=)

  shoryuken_level_str = (ENV["SHORYUKEN_LOG_LEVEL"] || "info").upcase
  shoryuken_level = Logger.const_get(shoryuken_level_str) rescue Logger::INFO
  Shoryuken.logger.level = shoryuken_level if Shoryuken.logger.respond_to?(:level=)

  logger.info("[BOOT] Shoryuken logger wired to Sparko.logger level=#{shoryuken_level}")

  if ENV["WORKER_HEARTBEAT"] == "1"
    Thread.new do
      loop do
        logger.info("[HEARTBEAT] shoryuken alive pid=#{Process.pid} t=#{Time.now}")
        sleep Integer(ENV["WORKER_HEARTBEAT_SECONDS"] || "15")
      end
    end
    logger.info("[BOOT] Worker heartbeat enabled")
  end
rescue StandardError => e
  warn "[BOOT] Shoryuken logger init failed: #{e.class}: #{e.message}"
  warn e.backtrace&.first(10)&.join("\n")
end

# ----------------------------
# STALL PROBE (enable with WORKER_STALL_PROBE=1)
# Logs queue attrs + thread health periodically so you can see
# "messages waiting but no worker starts" vs "nothing in queue".
# ----------------------------
if ENV["WORKER_STALL_PROBE"] == "1"
  Thread.new do
    logger = Sparko.logger
    region = ENV.fetch("AWS_REGION", "us-east-1")
    queue_url = ENV["SQS_QUEUE_URL"]
    interval = Integer(ENV["WORKER_STALL_PROBE_SECONDS"] || "10")

    sqs =
      begin
        Aws::SQS::Client.new(region: region)
      rescue StandardError => e
        logger.error("[STALL_PROBE] failed to init SQS client: #{e.class} #{e.message}")
        nil
      end

    logger.warn("[STALL_PROBE] enabled pid=#{Process.pid} region=#{region.inspect} queue_url=#{queue_url.inspect} every=#{interval}s")

    loop do
      sleep interval
      begin
        threads = Thread.list
        runnable = threads.count { |t| t.status == "run" || t.status == "runnable" }
        sleeping = threads.count { |t| t.status == "sleep" }
        dead     = threads.count { |t| t.status == false }

        attrs = nil
        if sqs && queue_url && !queue_url.empty?
          attrs = sqs.get_queue_attributes(
            queue_url: queue_url,
            attribute_names: ["ApproximateNumberOfMessages", "ApproximateNumberOfMessagesNotVisible"]
          ).attributes
        end

        aws_ident = nil
        if ENV["WORKER_STALL_PROBE_IDENTITY"] == "1"
          ident = Aws::STS::Client.new(region: region).get_caller_identity
          aws_ident = "#{ident.account} #{ident.arn}"
        end

        logger.warn(
          "[STALL_PROBE] pid=#{Process.pid} threads=#{threads.size} run=#{runnable} sleep=#{sleeping} dead=#{dead} " \
          "queue_attrs=#{attrs.inspect} aws_ident=#{aws_ident.inspect}"
        )
      rescue StandardError => e
        logger.error("[STALL_PROBE] error #{e.class}: #{e.message}")
      end
    end
  end
end

# ----------------------------
# DEEP DIAGNOSTICS (enable with WORKER_DIAG=1)
# - Logs Shoryuken fetch loop activity (receive_message calls)
# - Logs queue visible/not-visible counts periodically
# ----------------------------
# ----------------------------
# DEEP DIAGNOSTICS (enable with WORKER_DIAG=1)
# Patch Aws::SQS::Client#receive_message to see if Shoryuken is polling at all
# ----------------------------
if ENV["WORKER_DIAG"] == "1"
  logger = Sparko.logger
  logger.warn("[DIAG] enabling receive_message patch")

  module ::SparkoAwsSqsReceivePatch
    def receive_message(params = {})
      t0 = Process.clock_gettime(Process::CLOCK_MONOTONIC)
      q = params[:queue_url] || params["queue_url"]

      Sparko.logger.warn(
        "[DIAG] receive_message -> queue_url=#{q.inspect} " \
        "wait_time_seconds=#{params[:wait_time_seconds].inspect} " \
        "max_number_of_messages=#{params[:max_number_of_messages].inspect}"
      )

      resp = super

      dt = ((Process.clock_gettime(Process::CLOCK_MONOTONIC) - t0) * 1000).round(1)
      n = resp&.messages&.size || 0

      Sparko.logger.warn("[DIAG] receive_message <- msgs=#{n} dur_ms=#{dt}")
      resp
    rescue => e
      dt = ((Process.clock_gettime(Process::CLOCK_MONOTONIC) - t0) * 1000).round(1) rescue nil
      Sparko.logger.error("[DIAG] receive_message ERROR dur_ms=#{dt} #{e.class}: #{e.message}")
      raise
    end
  end

  Aws::SQS::Client.prepend(::SparkoAwsSqsReceivePatch)

  # Optional thread dump on USR1 (keep this, it's gold)
  trap("USR1") do
    Sparko.logger.error("[DIAG] ===== THREAD DUMP pid=#{Process.pid} =====")
    Thread.list.each do |t|
      Sparko.logger.error("[DIAG] thread=#{t.object_id} status=#{t.status.inspect}")
      bt = t.backtrace
      Sparko.logger.error(bt ? bt.first(40).join("\n") : "(no backtrace)")
    end
    Sparko.logger.error("[DIAG] ===== END THREAD DUMP =====")
  end
end

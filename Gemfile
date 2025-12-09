# frozen_string_literal: true

source 'https://rubygems.org'

# Configuration
gem 'figaro', '~> 1.0'
gem 'openssl', '~> 3.3.1'

# Global Debugging
gem 'pry'
gem 'rake'

# Database
gem 'hirb'
gem 'sequel', '~> 5.0'

# Web application
gem 'logger', '~> 1.0'
gem 'puma', '~> 6.0'
gem 'rack-session', '~> 0'
gem 'roda', '~> 3.0'
gem 'slim', '~> 5.0'

# Validation
gem 'dry-monads', '~> 1.0'
gem 'dry-struct', '~> 1.0'
gem 'dry-transaction', '~> 0'
gem 'dry-types', '~> 1.0'
gem 'dry-validation', '~> 1.0'

# Networking
gem 'http', '~> 5.3.1'

group :development, :test do
  gem 'sqlite3', '~> 1.0'
end

# Testing
group :test do
  gem 'minitest', '~> 5.20'
  gem 'minitest-rg', '~> 5.2'
  gem 'simplecov', '~> 0'
  gem 'vcr', '~> 6'
  gem 'webmock', '~> 3'
end

# Development
group :development do
  gem 'flog'
  gem 'reek'
  gem 'rerun'
  gem 'rubocop'
  gem 'rubocop-minitest'
  gem 'rubocop-rake'
  gem 'rubocop-sequel'
end

# Production
group :production do
  gem 'pg'
end

# Utiliy tools
gem 'engtagger'
gem 'nokogiri'
gem 'ostruct'
gem 'rexml'
gem 'tactful_tokenizer'

# Presentation
gem 'multi_json'
gem 'roar'

# API testing
gem 'rack-test'

# API Cache
gem 'rack-cache'
gem 'redis'

# Parallelism
gem 'aws-sdk-sqs'
gem 'shoryuken'

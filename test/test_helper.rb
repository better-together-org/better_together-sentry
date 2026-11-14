# frozen_string_literal: true

$LOAD_PATH.unshift File.expand_path('../lib', __dir__)
require 'minitest/autorun'
require_relative 'support/fake_platform'

# Runs a block with the given environment variables set (nil deletes), then restores them.
module EnvHelper
  def with_env(values)
    original = values.keys.to_h { |key| [key, ENV.fetch(key, nil)] }
    values.each { |key, value| value.nil? ? ENV.delete(key) : ENV[key] = value }
    yield
  ensure
    original.each { |key, value| value.nil? ? ENV.delete(key) : ENV[key] = value }
  end
end

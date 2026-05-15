# frozen_string_literal: true

module BetterTogether
  module Sentry
    class Railtie < ::Rails::Railtie
      initializer 'better_together.sentry.register_adapter' do
        next unless defined?(BetterTogether)
        next unless defined?(::Sentry)

        BetterTogether.register_adapter(:error_reporting, :sentry, Reporter.new)
      end
    end
  end
end

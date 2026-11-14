# frozen_string_literal: true

module BetterTogether
  module Sentry
    # Answers "did this person agree to the analytics category?" for server-side code, from whatever
    # the host passes in the reporting context (`consent:`) or exposes on `Current`. No answer means no.
    module ConsentGate
      module_function

      def analytics?(context = {})
        decision = context[:consent] || context['consent'] || current_decision
        granted?(decision, 'analytics')
      end

      def current_decision
        return unless defined?(::Current) && ::Current.respond_to?(:consent)

        ::Current.consent
      end

      def granted?(decision, category)
        case decision
        when Hash then decision[category] == true || decision[category.to_sym] == true
        when Array then decision.map(&:to_s).include?(category)
        else false
        end
      end
    end
  end
end

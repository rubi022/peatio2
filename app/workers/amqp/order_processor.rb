# frozen_string_literal: true

module Workers
  module AMQP
    class OrderProcessor < Base
      def initialize
        Rails.logger.info("Resubmit orders")
        Order.spot.where(state: ::Order::PENDING).find_each do |order|
          Order.submit(order.id)
        rescue StandardError => e
          ::AMQP::Queue.enqueue(:trade_error, e.message)
          report_exception e, true, order: order.as_json

          raise e if is_db_connection_error?(e)
        end
        Rails.logger.info("Orders are resubmited")
      end

      def process(payload)
        case payload['action']
        when 'submit'
          Order.submit(payload.dig('order', 'id'))
        when 'cancel'
          Order.cancel(payload.dig('order', 'id'))
        end
      rescue StandardError => e
        ::AMQP::Queue.enqueue(:trade_error, e.message)
        report_exception e, true, payload: payload

        raise e if is_db_connection_error?(e)
      end
    end
  end
end

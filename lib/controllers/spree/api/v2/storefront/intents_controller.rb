module Spree
  module Api
    module V2
      module Storefront
        class IntentsController < ::Spree::Api::BaseController
          # include Spree::Api::V2::Storefront::OrderConcern

          def handle_response
            if params['response']['error']
              invalidate_payment
              render_error_payload(params['response']['error']['message'])
            else
              render_serialized_payload { { message: I18n.t('spree.payment_successfully_authorized') } }
            end
          end

          def render_serialized_payload(status = 200)
            render json: yield, status: status, content_type: content_type
          rescue ArgumentError => exception
            render_error_payload(exception.message, 400)
          end

          def render_error_payload(error, status = 422)
            if error.is_a?(Struct)
              render json: { error: error.to_s, errors: error.to_h }, status: status, content_type: content_type
            elsif error.is_a?(String)
              render json: { error: error }, status: status, content_type: content_type
            end
          end

          private

          def invalidate_payment
            payment = spree_current_order.payments.find_by!(response_code: params['response']['error']['payment_intent']['id'])
            payment.update(state: 'failed', intent_client_key: nil)
          end

          # private methods from include Spree::Api::V2::Storefront::OrderConcern

          def render_order(result)
            if result.success?
              render_serialized_payload { serialized_current_order }
            else
              render_error_payload(result.error)
            end
          end

          def ensure_order
            raise ActiveRecord::RecordNotFound if spree_current_order.nil?
          end

          def order_token
            request.headers['X-Spree-Order-Token'] || params[:order_token]
          end

          def spree_current_order
            @spree_current_order ||= find_spree_current_order
          end

          def find_spree_current_order
            Spree::Api::Dependencies.storefront_current_order_finder.constantize.new.execute(
              store: current_store,
              user: spree_current_user,
              token: order_token,
              currency: current_currency
            )
          end

          def serialize_order(order)
            resource_serializer.new(order.reload, include: resource_includes, fields: sparse_fields).serializable_hash
          end

          def serialized_current_order
            serialize_order(spree_current_order)
          end

        end
      end
    end
  end
end

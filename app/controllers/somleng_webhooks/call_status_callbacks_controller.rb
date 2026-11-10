module SomlengWebhooks
  class CallStatusCallbacksController < SomlengWebhooksController
    def create
      ExecuteWorkflowJob.perform_later(
        HandleStatusCallback.to_s,
        delivery_attempt_id: params.fetch(:delivery_attempt_id),
        params: request.request_parameters,
        parser: Somleng::Parser::CallStatusCallbackParser.to_s
      )
      head(:no_content)
    end
  end
end

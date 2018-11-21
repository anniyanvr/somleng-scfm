class CallFlowLogic::PlayMessageStartRapidproFlow < CallFlowLogic::PlayMessage
  def run!
    super
    return unless event.phone_call.completed?

    StartRapidproFlowJob.perform_later(event)
  end
end
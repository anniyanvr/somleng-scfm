class Event::User < Event::Base
  VALID_EVENTS = ["invite"]

  private

  def fire_event!
    case event
    when "invite"
      eventable.invite!
    end
    true
  end

  def valid_events
    eventable && VALID_EVENTS || []
  end
end
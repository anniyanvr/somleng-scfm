require "rails_helper"

RSpec.describe FetchRemoteCallJob do
  describe "#perform" do
    it "updates the remote status of the call" do
      account = create(:account, :with_twilio_provider)
      phone_call = create(:phone_call, :in_progress, account: account)
      stub_twilio_request(
        response: { body: { "status" => "in-progress" }.to_json }
      )

      FetchRemoteCallJob.new.perform(phone_call)

      phone_call.reload
      expect(WebMock).to have_requested(
        :get,
        "https://api.twilio.com/2010-04-01/Accounts/#{account.twilio_account_sid}/Calls/#{phone_call.remote_call_id}.json"
      )
      expect(phone_call.remote_response).to be_present
      expect(phone_call.remote_status).to eq("in-progress")
      expect(phone_call).to be_in_progress
    end

    it "completes a call" do
      account = create(:account, :with_twilio_provider)
      phone_call = create(:phone_call, :in_progress, account: account)
      stub_twilio_request(
        response: { body: { "status" => "completed", "duration" => "87" }.to_json }
      )

      FetchRemoteCallJob.new.perform(phone_call)

      phone_call.reload
      expect(phone_call.remote_response).to be_present
      expect(phone_call.duration).to eq(87)
      expect(phone_call).to be_completed
    end

    def stub_twilio_request(response:)
      stub_request(:get, %r{https://api.twilio.com}).to_return(response)
    end
  end
end

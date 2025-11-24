require "multi_json"
require "spec_helper"

describe OmniAuth::Strategies::Bitbucket do
  let(:app) do
    Rack::Builder.new do |b|
      b.use Rack::Session::Cookie, secret: "test_secret"
      b.use OmniAuth::Strategies::Bitbucket, "test_key", "test_secret"
      b.run lambda { |env| [200, {}, ["Hello"]] }
    end.to_app
  end

  # Fixture: spec/fixtures/user_response.json
  let(:user_response_body) do
    File.read(File.expand_path("../../../fixtures/user_response.json", __FILE__))
  end

  # Fixture: spec/fixtures/user_emails_response.json
  let(:emails_response_body) do
    File.read(File.expand_path("../../../fixtures/user_emails_response.json", __FILE__))
  end

  before do
    # Fixture: spec/fixtures/user_response.json
    stub_request(:get, "#{OmniAuth::Strategies::Bitbucket::SITE_URL}#{OmniAuth::Strategies::Bitbucket::USER_API_PATH}")
      .to_return(status: 200, body: user_response_body, headers: { "Content-Type" => "application/json" })

    # Fixture: spec/fixtures/user_emails_response.json
    stub_request(:get, "#{OmniAuth::Strategies::Bitbucket::SITE_URL}#{OmniAuth::Strategies::Bitbucket::USER_EMAILS_API_PATH}")
      .to_return(status: 200, body: emails_response_body, headers: { "Content-Type" => "application/json" })
  end

  describe "#options" do
    subject { OmniAuth::Strategies::Bitbucket.new(app, "test_key", "test_secret") }

    it "sets the correct client options" do
      expect(subject.options.client_options.site).to eq(OmniAuth::Strategies::Bitbucket::SITE_URL)
      expect(subject.options.client_options.authorize_url).to eq(OmniAuth::Strategies::Bitbucket::AUTHORIZE_URL)
      expect(subject.options.client_options.token_url).to eq(OmniAuth::Strategies::Bitbucket::TOKEN_URL)
    end
  end

  describe "#uid" do
    subject do
      strategy = OmniAuth::Strategies::Bitbucket.new(app, "test_key", "test_secret")
      access_token_double = double("access_token")
      # Fixture: spec/fixtures/user_response.json
      allow(access_token_double).to receive(:get).with(OmniAuth::Strategies::Bitbucket::USER_API_PATH).and_return(
        double("response", body: user_response_body)
      )
      # Fixture: spec/fixtures/user_emails_response.json
      allow(access_token_double).to receive(:get).with(OmniAuth::Strategies::Bitbucket::USER_EMAILS_API_PATH).and_return(
        double("response", body: emails_response_body)
      )
      allow(strategy).to receive(:access_token).and_return(access_token_double)
      strategy
    end

    it "returns the account_id from raw_info" do
      # Fixture: spec/fixtures/user_response.json
      expect(subject.uid).to eq("123456:abcdef12-3456-7890-abcd-ef1234567890")
    end
  end

  describe "#raw_info" do
    subject do
      OmniAuth::Strategies::Bitbucket.new(app, "test_key", "test_secret").tap do |strategy|
        access_token_double = double("access_token")
        allow(access_token_double).to receive(:get).with(OmniAuth::Strategies::Bitbucket::USER_API_PATH).and_return(
          double("response", body: user_response_body)
        )
        allow(access_token_double).to receive(:get).with(OmniAuth::Strategies::Bitbucket::USER_EMAILS_API_PATH).and_return(
          double("response", body: emails_response_body)
        )
        allow(strategy).to receive(:access_token).and_return(access_token_double)
      end
    end

    it "returns the user information with merged email" do
      raw_info = subject.raw_info

      # Fixture: spec/fixtures/user_response.json
      expect(raw_info["uuid"]).to eq("{12345678-1234-1234-1234-123456789abc}")
      expect(raw_info["display_name"]).to eq("Test User")
      expect(raw_info["username"]).to eq("testuser")
      expect(raw_info["nickname"]).to eq("Test User")
      expect(raw_info["account_id"]).to eq("123456:abcdef12-3456-7890-abcd-ef1234567890")
      # Fixture: spec/fixtures/user_emails_response.json
      expect(raw_info["email"]).to eq("testuser@example.com")
      # Fixture: spec/fixtures/user_response.json
      expect(raw_info["type"]).to eq("user")
      expect(raw_info["created_on"]).to eq("2020-01-01T00:00:00.000000+00:00")
    end

    it "memoizes the result" do
      access_token_double = double("access_token")
      # Fixture: spec/fixtures/user_response.json
      allow(access_token_double).to receive(:get).with("/api/2.0/user").once.and_return(
        double("response", body: user_response_body)
      )
      # Fixture: spec/fixtures/user_emails_response.json
      allow(access_token_double).to receive(:get).with("/api/2.0/user/emails").once.and_return(
        double("response", body: emails_response_body)
      )
      allow(subject).to receive(:access_token).and_return(access_token_double)

      first_call = subject.raw_info
      second_call = subject.raw_info

      expect(first_call).to eq(second_call)
      expect(first_call.object_id).to eq(second_call.object_id)
    end
  end

  describe "#info" do
    subject do
      OmniAuth::Strategies::Bitbucket.new(app, "test_key", "test_secret").tap do |strategy|
        access_token_double = double("access_token")
        allow(access_token_double).to receive(:get).with(OmniAuth::Strategies::Bitbucket::USER_API_PATH).and_return(
          double("response", body: user_response_body)
        )
        allow(access_token_double).to receive(:get).with(OmniAuth::Strategies::Bitbucket::USER_EMAILS_API_PATH).and_return(
          double("response", body: emails_response_body)
        )
        allow(strategy).to receive(:access_token).and_return(access_token_double)
      end
    end

    it "returns the correct info hash" do
      info = subject.info

      # Fixture: spec/fixtures/user_response.json
      expect(info[:name]).to eq("Test User")
      expect(info[:username]).to eq("testuser")
      # Fixture: spec/fixtures/user_emails_response.json
      expect(info[:email]).to eq("testuser@example.com")
      # Fixture: spec/fixtures/user_response.json
      expect(info[:avatar]).to eq("https://secure.gravatar.com/avatar/abcdef1234567890abcdef1234567890?d=https%3A%2F%2Favatar-management--avatars.us-west-2.prod.public.atl-paas.net%2Finitials%2FTU-1.png")
      expect(info[:avatar]).to match(/\Ahttps?:\/\//)
    end
  end

  describe "#callback_url" do
    subject do
      OmniAuth::Strategies::Bitbucket.new(app, "test_key", "test_secret").tap do |strategy|
        allow(strategy).to receive(:full_host).and_return("http://localhost:3000")
        allow(strategy).to receive(:script_name).and_return("")
        allow(strategy).to receive(:callback_path).and_return("/users/auth/bitbucket/callback")
      end
    end

    it "returns the correct callback URL" do
      expect(subject.callback_url).to eq("http://localhost:3000/users/auth/bitbucket/callback")
    end

    context "with a script_name" do
      before do
        allow(subject).to receive(:script_name).and_return("/app")
      end

      it "includes the script_name in the callback URL" do
        expect(subject.callback_url).to eq("http://localhost:3000/app/users/auth/bitbucket/callback")
      end
    end
  end
end

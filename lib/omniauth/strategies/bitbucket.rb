require "omniauth-oauth2"

module OmniAuth
  module Strategies
    class Bitbucket < OmniAuth::Strategies::OAuth2
      SITE_URL = "https://bitbucket.org"
      AUTHORIZE_URL = "https://bitbucket.org/site/oauth2/authorize"
      TOKEN_URL = "https://bitbucket.org/site/oauth2/access_token"
      USER_API_PATH = "/api/2.0/user"
      USER_EMAILS_API_PATH = "/api/2.0/user/emails"

      # ----------------------------------------------------------------------------
      # This is where you pass the options you would pass when
      # initializing your consumer from the OAuth gem.
      option :client_options, {
        :site => SITE_URL,
        :authorize_url => AUTHORIZE_URL,
        :token_url => TOKEN_URL
      }

      # The methods below are called after authentication has succeeded.
      # If possible, you should try to set the UID without making
      # additional calls (if the user id is returned with the token
      # or as a URI parameter). This may not be possible with all
      # providers.
      #
      # More info on what the fields mean: https://public.amplenote.com/j23hekAmVpQWsJcWrUT1G3eC
      #
      # For future maintainers:
      #   If any of these field mappings are updated, consider updating the gitclear/gitclear repo files as well:
      #     `vendor/gems/repo_interface/app/lib/external_user/bitbucket_user.rb`

      # ----------------------------------------------------------------------------
      # Account ID is preferred, recommended and future-proof option as a unique identifier for users.
      uid { raw_info["account_id"] }

      # ----------------------------------------------------------------------------
      info do
        {
          :name => raw_info["display_name"],
          :username => raw_info["username"] || raw_info["nickname"],
          :avatar => raw_info.dig("links", "avatar", "href"),
          :email => raw_info["email"]
        }
      end

      # ----------------------------------------------------------------------------
      def raw_info
        @raw_info ||= begin
          user_data = MultiJson.decode(access_token.get(USER_API_PATH).body)
          primary_email_data = MultiJson.decode(access_token.get(USER_EMAILS_API_PATH).body)["values"].find { |email| email["is_primary"] }
          user_data.merge!("email" => primary_email_data["email"]) if primary_email_data
          user_data
        end
      end

      # ----------------------------------------------------------------------------
      def callback_url
        full_host + script_name + callback_path
      end
    end
  end
end

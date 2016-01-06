#!/usr/bin/env ruby
#
# Check hubot on slack
#

require 'sensu-plugin/check/cli'
require 'net/http'
require 'net/https'
require 'json'

class CheckHubotOnSlack < Sensu::Plugin::Check::CLI
  option :slackbot_token,
    :short => '-s SLACKBOT_TOKEN',
    :description => 'Slackbot reposonse token (for sending messages)'

  option :api_token,
    :short => '-a API_TOKEN',
    :description => 'Hubots Slack API token (for reading messages)'

  option :hubot_name,
    :short => '-h HUBOT_NAME',
    :description => 'Hubots username (in slack)'

  option :slack_channel,
    :short => '-c SLACK_CHANNEL',
    :description => 'Slack channel to attempt to talk to hubot in'

  option :slack_channel_private,
    :short => '-p',
    :description => 'Is the channel private',
    :boolean => true,
    :default => false

  option :slack_team,
    :short => '-t SLACK_TEAM',
    :description => 'Slack Team to talk to hubot in.'

  def get_json(http, path)
    resp = http.get(path)
    return JSON.parse(resp.body)
  end

  def run
    url = "https://#{config[:slack_team]}.slack.com/services/hooks/slackbot"
    url += "?token=#{config[:slackbot_token]}&channel=%23#{config[:slack_channel]}"
    uri = URI.parse(url)

    # init connection to slack api
    http = Net::HTTP.new(uri.host, 443)
    http.use_ssl = true

    # Figure out the user ID for the given user
    users = get_json(http,
      "/api/users.list?token=#{config[:api_token]}&presence=1")
    user_id = nil
    users['members'].each do |user|
      if user['name'] == config[:hubot_name]
        user_id = user['id']
        if user['presence'] != 'active'
          critical "hubot '#{config[:hubot_name]}' is not present in slack"
        end
      end
    end

    # Error out if given username doesn't exist
    unknown "No user with name '#{config[:hubot_name]}'" if not user_id

    if config[:slack_channel_private] == true
      channels_type = 'groups'
    else
      channels_type = 'channels'
    end

    # Figure out the channel ID for the given channel
    channels = get_json(http,
      "/api/#{channels_type}.list?token=#{config[:api_token]}&exclude_archived=1")
    channel_id = nil
    channels[channels_type].each do |channel|
      if channel['name'] == config[:slack_channel]
        channel_id = channel['id']
      end
    end

    # Error out if given slack channel doesn't exist
    unknown "No channel with name '#{config[:slack_channel]}'" if not channel_id

    # Trigger a response from hubot using slackbot webhooks
    slack_message = "#{config[:hubot_name]} echo feeling alive"
    headers = {'Content-Type'=> 'application/x-www-form-urlencoded'}
    resp, data = http.post("#{uri.path}?#{uri.query}", slack_message, headers)

    unknown "Could not send message to hubot via slack: #{resp.body}" if resp.body != 'ok'

    # Read the last response to ensure hubot has responded
    messages = get_json(http,
      "/api/#{channels_type}.history?token=#{config[:api_token]}&channel=#{channel_id}&count=1")

    unknown "Failed to get message history: #{messages}" if not messages['ok']

    critical "No messages found" if messages['messages'].length != 1

    message = messages['messages'][0]

    critical "Last response not from hubot '#{config[:hubot_name]}'" if message['user'] != user_id

    critical "Unexpected hubot response #{message['text']}" if message['text'] != "feeling alive"

    ok
  end
end

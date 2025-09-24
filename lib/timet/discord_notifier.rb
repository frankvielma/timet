require 'net/http'
require 'uri'
require 'json'

module Timet
  # Handles sending notifications to Discord via webhooks for Pomodoro events.
  #
  # This class provides methods to send structured messages to a Discord channel
  # when a Pomodoro session starts, ends, or a break ends. It relies on a
  # Discord webhook URL configured via the `DISCORD_WEBHOOK_URL` environment variable.
  class DiscordNotifier
    DISCORD_WEBHOOK_URL = ENV.fetch('DISCORD_WEBHOOK_URL', nil)

    # Sends a notification to the configured Discord webhook.
    #
    # @param message_content [String] The main text content of the message.
    # @param embed_data [Hash, nil] An optional hash representing a Discord embed object.
    #   See Discord API documentation for embed structure.
    # @return [void]
    def self.send_notification(message_content, embed_data = nil)
      return unless DISCORD_WEBHOOK_URL

      uri = URI.parse(DISCORD_WEBHOOK_URL)
      http = Net::HTTP.new(uri.host, uri.port)
      http.use_ssl = true

      request = Net::HTTP::Post.new(uri.path, { 'Content-Type' => 'application/json' })

      payload = {
        content: message_content,
        username: 'Timet Pomodoro',
        avatar_url: 'https://gravatar.com/avatar/b4921f111e1d481e3f5f35101432bce5'
      }
      payload[:embeds] = [embed_data] if embed_data

      request.body = payload.to_json

      response = http.request(request)
      unless response.is_a?(Net::HTTPSuccess)
        puts "Failed to send Discord notification: #{response.code} - #{response.body}"
      end
    rescue StandardError => e
      puts "Error sending Discord notification: #{e.message}"
    end

    # Sends a notification indicating that a Pomodoro work session has started.
    #
    # The notification includes a title, description, color, and fields for duration
    # and the next scheduled event (short break).
    #
    # Sends a notification indicating that a Pomodoro work session has started.
    #
    # The notification includes a title, description, color, and fields for duration
    # and the next scheduled event (short break).
    #
    # @param duration [Integer] The duration of the Pomodoro session in minutes.
    # @return [void]
    def self.pomodoro_started(duration)
      embed = {
        title: 'Pomodoro Session Started! 🍅',
        description: "Time to focus for #{duration} minutes!",
        color: 0x00FF00, # Green
        fields: [
          { name: 'Duration', value: "#{duration} minutes", inline: true },
          { name: 'Next Up', value: 'Short Break', inline: true }
        ],
        timestamp: Time.now.utc.iso8601
      }
      send_notification('Focus time!', embed)
    end

    # Sends a notification indicating that a Pomodoro work session has ended.
    #
    # The notification includes a title, description, color, and fields for duration
    # and the next scheduled event (work session).
    #
    # Sends a notification indicating that a Pomodoro work session has ended.
    #
    # The notification includes a title, description, color, and fields for duration
    # and the next scheduled event (work session).
    #
    # @param duration [Integer] The duration of the Pomodoro session in minutes.
    # @return [void]
    def self.pomodoro_ended(duration)
      break_duration = (duration / 5).to_i # Assuming a 1/5th break duration
      break_duration = 5 if break_duration == 0 # Minimum 5 minute break
      embed = {
        title: 'Pomodoro Session Ended! 🎉',
        description: "Time for a #{break_duration} minute break!",
        color: 0xFFA500, # Orange
        fields: [
          { name: 'Duration', value: "#{break_duration} minutes", inline: true },
          { name: 'Next Up', value: 'Work Session', inline: true }
        ],
        timestamp: Time.now.utc.iso8601
      }
      send_notification('Break time!', embed)
    end

    # Sends a notification indicating that a break has ended and it's time to return to work.
    #
    # The notification includes a title, description, and color.
    #
    # @return [void]
    def self.break_ended
      embed = {
        title: 'Break Ended! Back to Work! 🚀',
        description: 'Your short break is over. Time to start a new Pomodoro!',
        color: 0xFF0000, # Red
        timestamp: Time.now.utc.iso8601
      }
      send_notification('Break over!', embed)
    end
  end
end

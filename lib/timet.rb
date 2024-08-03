# frozen_string_literal: true

require_relative "timet/version"
require "thor"

module Timet
  class CLI < Thor
    desc "start", "start time tracking"
    # method_option :delete, aliases: "-d", desc: "Delete the file after parsing it"
    def start
      puts "start"
    end

    desc "stop", "stop time tracking"
    def stop
      puts "stop"
    end

    def self.exit_on_failure?
      true
    end
  end
end

# frozen_string_literal: true

require_relative "version"
require "thor"

module Timet
  class Application < Thor
    def initialize(*args)
      super
      @db = Timet::Database.new
    end

    # ww start timet-sqlite
    # Tracking "timet-sqlite"
    # Started 2024-08-05T11:53:48
    # Current                  48
    # Total               0:00:00
    desc "start", "start time tracking"
    # method_option :delete, aliases: "-d", desc: "Delete the file after parsing it"

    def start
      start = Time.now.to_i
      tag = "test"
      @db.insert_item(start, tag)
    end

    # ww stop
    # Recorded "timet-sqlite"
    #   Started 2024-08-05T11:53:48
    #   Ended                 54:11
    #   Total               0:00:23
    desc "stop", "stop time tracking"
    def stop
      stop = Time.now.to_i
      @db.update(stop)
    end

    def self.exit_on_failure?
      true
    end
  end
end

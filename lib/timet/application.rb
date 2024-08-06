# frozen_string_literal: true

require_relative "version"
require "thor"

module Timet
  # Tracks time spent on various tasks.
  class Application < Thor
    def initialize(*args)
      super
      @db = Timet::Database.new
    end

    desc "start <tag>", "start time tracking"
    def start(tag)
      start = Time.now.to_i
      @db.insert_item(start, tag) if @db.incomplete_item?
      puts "Tracking <#{tag}>"
      puts "Started: #{Time.at(start)}"
      puts "Total: #{@db.total_time}"
    end

    desc "stop", "stop time tracking"
    def stop
      stop = Time.now.to_i
      @db.update(stop) if @db.complete_item?
      result = @db.last_item

      return if result.nil?

      puts "Recorded <#{result[3]}>"
      puts "Started: #{Time.at(result[1])}"
      puts "Total: #{@db.total_time}"
    end

    def self.exit_on_failure?
      true
    end
  end
end

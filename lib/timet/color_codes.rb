# frozen_string_literal: true

module Timet
  # ColorCodes class
  class ColorCodes
    RESET = "\u001b[0m"
    UNDERLINE = "\e[4m"
    BLINK = "\e[5m"

    def self.reset
      RESET
    end

    def self.underline
      UNDERLINE
    end

    def self.blink
      BLINK
    end

    def self.color(num)
      "\u001b[38;5;#{num}m"
    end
  end
end

# Extend String class globally
class String
  def gray
    "#{Timet::ColorCodes.color(242)}#{self}#{Timet::ColorCodes.reset}"
  end

  def red
    "#{Timet::ColorCodes.color(1)}#{self}#{Timet::ColorCodes.reset}"
  end

  def blue
    "#{Timet::ColorCodes.color(12)}#{self}#{Timet::ColorCodes.reset}"
  end

  def underline
    "#{Timet::ColorCodes.underline}#{self}#{Timet::ColorCodes.reset}"
  end

  def blink
    "#{Timet::ColorCodes.blink}#{self}#{Timet::ColorCodes.reset}"
  end

  def green
    "#{Timet::ColorCodes.color(10)}#{self}#{Timet::ColorCodes.reset}"
  end

  def color(num)
    "#{Timet::ColorCodes.color(num)}#{self}#{Timet::ColorCodes.reset}"
  end
end

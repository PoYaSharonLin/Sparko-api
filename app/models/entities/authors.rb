# frozen_string_literal: true

module AcaRadar
  # Formats for author name presentation
  module NameFormat
    FULL = ->(first, last) { [first, last].join(' ') }
    SHORT = ->(first, last) { "#{first[0]}. #{last}" }
    CITATION = ->(first, last) { "#{last}, #{first}" }
    INITIALS = lambda do |first, last|
      initials = first.split.map { |part| "#{part[0]}." }.join
      "#{initials}#{last[0]}."
    end
  end

  # Name parser to handle splitting logic
  class NameParser
    def self.parse(full_name)
      parts = full_name.to_s.strip.split
      case parts.size
      when 0 then DEFAULT_PARTS.dup
      when 1
        first = parts[0]
        [first, first]
      else [parts[0..-2].join(' '), parts[-1]]
      end
    end

    DEFAULT_PARTS = ['', ''].freeze
    private_constant :DEFAULT_PARTS
  end

  # Represents an Author, allowing the end-user to format the name in various ways
  class Author
    attr_reader :name, :first_name, :last_name

    def initialize(name)
      @name = name.to_s.strip
      @first_name, @last_name = NameParser.parse(@name)
    end

    # Default format: "First Last"
    def full
      format_with(NameFormat::FULL)
    end

    # Short format: "F. Last"
    def short
      format_with(NameFormat::SHORT)
    end

    # Citation format: "Last, First"
    def citation
      format_with(NameFormat::CITATION)
    end

    # Initials format: "F.L."
    def initials
      format_with(NameFormat::INITIALS)
    end

    # Custom format helper (choose :full, :short, :citation, or :initials)
    def format(formatter = NameFormat::FULL)
      format_with(formatter)
    end

    def to_s
      full
    end

    def to_h
      {
        name: name,
        first_name: first_name,
        last_name: last_name
      }.compact
    end

    private

    # Splits name into first and last components
    def format_with(formatter)
      formatter.call(@first_name, @last_name)
    end
  end
end

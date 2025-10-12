# frozen_string_literal: true

module AcaRadar
  # Represents an Author, allowing the end-user to format the name in various ways
  class Author
    attr_reader :name, :first_name, :last_name

    def initialize(name)
      @name = name.to_s.strip
      split_name
    end

    # Default format: "First Last"
    def full
      [first_name, last_name].compact.join(' ')
    end

    # Short format: "F. Last"
    def short
      return name if first_name.nil? || last_name.nil?

      "#{first_name[0]}. #{last_name}"
    end

    # Citation format: "Last, First"
    def citation
      return name if first_name.nil? || last_name.nil?

      "#{last_name}, #{first_name}"
    end

    # Initials format: "F.L."
    def initials
      return name if first_name.nil?

      first_name.split.map { |n| "#{n[0]}." }.join + (last_name ? "#{last_name[0]}." : '')
    end

    # Custom format helper (choose :full, :short, :citation, or :initials)
    def format(style = :full)
      case style
      when :short then short
      when :citation then citation
      when :initials then initials
      else full
      end
    end

    # --- Helpers ---

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
    def split_name
      parts = name.split
      if parts.size >= 2
        @first_name = parts[0..-2].join(' ')
        @last_name = parts[-1]
      else
        @first_name = parts.first
        @last_name = nil
      end
    end
  end
end

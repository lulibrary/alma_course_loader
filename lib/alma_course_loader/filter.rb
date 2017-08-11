require 'json'
require 'set'

module AlmaCourseLoader
  # Implements a filter with a call() method accepting a year, course and cohort
  # and returning true if the course should be processed, false otherwise.
  class Filter
    # The regular expression describing a filter string
    FILTER = /((?<extractor>[^+-]*)(?<mode>[+-]))?(?<value>.*)/

    # @!attribute [rw] extractor
    #   @return [Proc, Method] a block accepting a year, course and cohort and
    #     returning the value used in filter matching
    attr_accessor :extractor

    # @!attribute [rw] mode
    #   @return [Symbol] the filter comparison mode
    #     :include - the match must be true (include for processing)
    #     :exclude - the match must be false (exclude from processing)
    attr_accessor :mode

    # @!attribute [rw] values
    #   @return [Object] the value or collection to match against. This may be:
    #     Array|Hash|Set - the matched value must be in the collection
    #     Regexp         - the matched value must match the regexp
    #     Other          - the matched value must be equal to this value
    attr_accessor :values

    # Parses a filter string and returns a Filter instance
    # @param str [String] the filter string: [extractor][+|-]value
    #   where extractor is the optional name of an entry in the extractors hash,
    #   +|- optionally specifies the mode (+ = :include, - = :exclude),
    #   value is a JSON string specifying the value(s) to match
    # @param extractors [Hash<Symbol, Proc|Method>] a hash of named field
    #   extractors referenced by the filter string; this may include a nil
    #   key which specifies the default extactor if not given in the filter
    #   string
    # @raise [ArgumentError] if the filter string is invalid
    def self.parse(str = nil, extractors = nil)
      # Parse the filter string
      raise ArgumentError, 'expected filter' if str.nil? || str.empty?
      match = FILTER.match(str)
      raise ArgumentError, "invalid filter: #{str}" if match.nil?
      # The default mode is :include unless :exclude is specified
      mode = match[:mode] == '-' ? :exclude : :include
      # Get the named extractor from the hash or block
      extractor = parse_extractor(match, extractors)
      # Get the filter value(s)
      value = parse_value(match)
      # Return an instance using the filter string values
      new(value, mode, extractor)
    end

    # Returns the extractor Proc specified by a parsed filter string
    # @param match [MatchData] the parsed filter string
    # @param extractors [Hash<Symbol, Proc|Method>] the extractors
    # @raise [ArgumentError] if a specified extractor is invalid or there is no
    #   default extractor in extractors when required
    def self.parse_extractor(match, extractors = nil)
      raise ArgumentError, 'extractors required' \
        if extractors.nil? || extractors.empty?
      e = match[:extractor] || ''
      # If no extractor is specified, use the default extractor
      extractor = extractors[e] || extractors[e.to_sym]
      return extractor unless extractor.nil?
      # If an extractor is specified, it is invalid; otherwise the default
      # extractor is specified but not present.
      msg = e.empty? ? 'no default extractor' : "invalid extractor: #{e}"
      raise ArgumentError, msg
    end
    private_class_method :parse_extractor

    # Returns a parsed regular expression
    # @param regexp [String] the regular expression from the value string
    # @return [Regexp] the parsed regular expression
    # @raise [ArgumentError] if the regular expression cannot be parsed
    def self.parse_regexp(regexp)
      # The regexp string always begins with /, the trailing / is optional
      last = regexp.end_with?('/') ? -2 : -1
      Regexp.new(regexp[1..last])
    rescue RegexpError
      raise ArgumentError, "invalid regular expression: #{regexp}"
    end

    # Returns the parsed value string
    # @param match [MatchData] the parsed filter string
    # @raise [ArgumentError] if the value string cannot be parsed
    def self.parse_value(match)
      value = match[:value]
      return nil if value.nil?
      # Parse strings starting with / as regular expressions
      return parse_regexp(value) if value.start_with?('/')
      # Parse all other strings as JSON
      JSON.parse(value)
    rescue JSON::ParserError
      raise ArgumentError, "invalid value: #{value}"
    end
    private_class_method :parse_value

    # Initialises a new Filter instance
    # @param values [Object] the value or collection to match against
    # @param mode [Symbol] the filter comparison mode
    #   :include - the filter returns true if value matches the filter values
    #   :exclude - the filter returns false if value matches the filter values
    # @param extractor [Proc, Method]  a block accepting a year, course and
    #   cohort and returning the value used in filter matching.
    #   This may be also passed as a code block.
    # @return [void]
    def initialize(values = nil, mode = nil, extractor = nil, &block)
      self.extractor = extractor || block
      self.mode = mode || :include
      self.values = values
      @matcher = value_matcher
    end

    # Applies the filter to a course/cohort
    # @param year [Object] the course year
    # @param course [Object] the course
    # @param cohort [Object] the course cohort
    # @return [Boolean] true if the course passes the filter, false otherwise
    def call(year = nil, course = nil, cohort = nil)
      # Get the value for matching
      value = extractor.call(year, course, cohort)
      # Test against the filter values (true => match, false => no match)
      result = @matcher.call(value)
      # If mode is :include, return true when the value matches
      # If mode is :exclude, return false when the value matches
      mode == :include ? result : !result
    end

    private

    # Returns true if the filter comparison value is a collection
    # @return [Boolean] true if the value is a collection, false otherwise
    def collection?
      values.is_a?(Array) || values.is_a?(Hash) || values.is_a?(Set)
    end

    # Returns a Proc which accepts a value and compares it against the filter
    # comparison values
    # @return [Proc] the value-matching block
    def value_matcher
      if collection?
        proc { |value| values.include?(value) }
      elsif values.is_a?(Regexp)
        proc { |value| values.match(value.to_s) }
      else
        proc { |value| value == values }
      end
    end
  end
end
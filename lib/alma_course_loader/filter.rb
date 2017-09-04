require 'json'
require 'set'

module AlmaCourseLoader
  # Methods for parsing filter specification strings
  # The primary method is parse_filter(str, extractors)
  module FilterParser
    # The regular expression describing a filter string: [!][extractor[op]]value
    FILTER = Regexp.new('\s*(?<negate>!)?\s*' \
                        '(' \
                        '(?<extractor>[^\s]*)\s+' \
                        '(?<method><=?|>=?|==|!=|~|=~|!~|keyin|valuein|in)\s+' \
                        ')?' \
                        '(?<value>.*)').freeze

    # Filter operators mapped to method names
    #
    # The operators in filter expressions are converted to methods called on
    # the filter value. Note that this means that the < and > operators are
    # inverted ('field < filter-value' is equivalent to 'filter-value.>(field)')
    # Operators not specified explicitly in FILTER_MAP are called directly as
    # methods.
    #
    # The hash value is either:
    # - a Symbol representing the method name to call on the filter value;
    # - an array [method-name-symbol, negated] containing the method name symbol
    #   and a Boolean indicating whether the method is implicitly negated,
    #   e.g. !~ is !match(); the default is no implicit negation.
    #
    FILTER_MAP = {
      :~ => :match,
      :=~ => :match,
      :!~ => [:match, true],
      :< => :>,
      :<= => :>=,
      :>= => :<=,
      :> => :<,
      :in => :include?,
      :keyin => :key?,
      :valuein => :value?
    }.freeze

    # Parses a filter string and returns the parsed filter string components
    # @param str [String] the filter string: [extractor][+|-]value
    #   where value is a JSON string specifying the value(s) to match,
    #         extractor is the optional name of an entry in the extractors hash,
    # @param extractors [Hash<Symbol, Proc|Method>] a hash of named field
    #   extractors referenced by the filter string; this may include a nil
    #   key which specifies the default extractor if not given in the filter
    #   string
    # @return [Array] the parsed filter string components:
    #   values, method, extractor, negate: [Object, Symbol, Proc, Boolean]
    # @raise [ArgumentError] if the filter string is invalid
    def parse_filter(str = nil, extractors = nil)
      # Parse the filter string
      raise ArgumentError, 'expected filter' if str.nil? || str.empty?
      match = FILTER.match(str)
      raise ArgumentError, "invalid filter: #{str}" if match.nil?
      # Get the filter value(s)
      value = Private.parse_value(match)
      # Get the method used to compare the filter value(s)
      method, method_negate = parse_method(match, value)
      # Get the effective negate flag
      negate = Private.negate_flag(match[:negate] == '!', method_negate)
      # Get the named extractor from the hash or block
      extractor = Private.parse_extractor(match, extractors)
      # Return the parsed filter string components
      [value, method, extractor, negate]
    end

    # Validates and returns the method symbol and negation flag
    # @param match [MatchData] the parsed filter string
    # @param values [Object] the filter value(s)
    # @return [Array] the method symbol and negate flag
    # @raise [ArgumentError] if the specified method is not supported by the
    #   filter values
    def parse_method(match, values)
      method_info = Private.method_symbol(match, values)
      method = method_info[0]
      unless values.respond_to?(method)
        raise ArgumentError, "invalid method: #{values.class.name}\##{method}"
      end
      method_info
    end

    # Private helpers
    module Private
      # Returns true if the value parameter is a collection
      # @param value [Object] the value to test
      # @return [Boolean] true if the value is a collection, false otherwise
      def self.collection?(value)
        value.is_a?(Array) || value.is_a?(Hash) || value.is_a?(Set)
      end

      # Returns a Proc implementing the filter match
      # @param values [Object] the filter values
      # @param method [Symbol] the method to call against the filter values
      # @param negate [Boolean] if true, negate the result of the method
      # @return [Proc] the Proc implementing the filter
      def self.matcher(values, method = nil, negate = false)
        method, negate = method_symbol(method, values) if method.nil?
        proc do |value|
          result = values.send(method, value)
          negate ? !result : result
        end
      end

      # Returns the method symbol or appropriate default if not specified
      # If no method is specified in the filter string, the default is :include?
      # for Arrays, Hashes and Sets, :match for regular expressions and :== for
      # everything else.
      # @param match [MatchData] the parsed filter string
      # @param values [Object] the filter value(s)
      # @return [Array] the method symbol and negation flag (false|true)
      def self.method_symbol(match, values)
        method = match[:method]
        # Return the default if no method is specified
        return method_symbol_default(values) if method.nil? || method.empty?
        method = method.to_sym
        # Return the method as specified unless it's mapped
        return method, false unless FILTER_MAP.key?(method)
        # Otherwise return the mapped filter
        method, negate = FILTER_MAP[method]
        [method, negate.nil? ? false : negate]
      end

      # Returns a default method symbol based on the filter value type
      # @param values [Object] the filter value(s)
      # @return [Array] the default method symbol and negation flag (false|true)
      def self.method_symbol_default(values)
        return :include?, false if collection?(values)
        return :match, false if values.is_a?(Regexp)
        [:==, false]
      end

      # Returns the actual filter negate flag based on the requested filter
      # negate flag and the compare method's negate flag
      # @param filter_negate [Boolean] the requested filter negate flag
      # @param method_negate [Boolean] the compare method's negate flag
      # @return [Boolean] the effective negate flag
      def self.negate_flag(filter_negate = false, method_negate = false)
        # The effective negate flag is true only if exactly one of the arguments
        # is true (filter_flag xor method_negate) since double negation cancels
        filter_negate != method_negate
      end

      # Returns the extractor Proc specified by a parsed filter string
      # @param match [MatchData] the parsed filter string
      # @param extractors [Hash<Symbol, Proc|Method>] the extractors
      # @raise [ArgumentError] if a specified extractor is invalid or there is
      #   no default extractor in extractors when required
      def self.parse_extractor(match, extractors = nil)
        raise ArgumentError, 'extractors required' \
          if extractors.nil? || extractors.empty?
        e = match[:extractor]
        extractor = extractors[e ? e.to_sym : nil]
        return extractor unless extractor.nil?
        raise ArgumentError, "invalid extractor: #{e}" if e
        raise ArgumentError, 'no default extractor'
      end

      # Returns a parsed regular expression
      # @param regexp [String] the regular expression from the value string
      # @return [Regexp] the parsed regular expression
      # @raise [ArgumentError] if the regular expression cannot be parsed
      def self.parse_regexp(regexp)
        # Remove enclosing / if present
        first = regexp.start_with?('/') ? 1 : 0
        last = regexp.end_with?('/') ? -2 : -1
        Regexp.new(regexp[first..last])
      rescue RegexpError
        raise ArgumentError, "invalid regular expression: #{regexp}"
      end

      # Returns the parsed value string
      # @param match [MatchData] the parsed filter string
      # @return [Object] the filter value(s)
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
    end
  end

  # Implements a course filter
  class Filter
    extend FilterParser

    # @!attribute [rw] extractor
    #   @return [Proc, Method] a block accepting a year, course and cohort and
    #     returning the value used in filter matching
    attr_accessor :extractor

    # @!attribute [rw] method
    #   @return [Symbol] the method to call against the values
    attr_accessor :method

    # @!attribute [rw] negate
    #   @return [Boolean] if true, the filter result is negated
    attr_accessor :negate

    # @!attribute [rw] values
    #   @return [Object] the value or collection to match against
    attr_accessor :values

    # Parses a filter string and returns a Filter instance
    # @param str [String] the filter string: [extractor][+|-]value
    #   where value is a JSON string specifying the value(s) to match,
    #         extractor is the optional name of an entry in the extractors hash,
    # @param extractors [Hash<Symbol, Proc|Method>] a hash of named field
    #   extractors referenced by the filter string; this may include a nil
    #   key which specifies the default extractor if not given in the filter
    #   string
    # @raise [ArgumentError] if the filter string is invalid
    def self.parse(str = nil, extractors = nil)
      new(*parse_filter(str, extractors))
    end

    # Initialises a new Filter instance
    # @param values [Object] the value or collection to match against
    # @param method [Symbol] the method symbol applied to the filter values
    # @param extractor [Proc, Method] a block accepting a year, course and
    #   cohort and returning the value used in filter matching.
    #   This may be also passed as a code block.
    # @param negate [Boolean] if true, negate the result of the filter
    # @raise [ArgumentError]
    # @return [void]
    def initialize(values = nil, method = nil, extractor = nil, negate = false,
                   &block)
      self.method = method
      self.negate = negate
      self.extractor = extractor || block
      self.values = values
      @matcher = matcher_proc(method)
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
      # Return the result with appropriate negation
      negate ? !result : result
    end

    private

    # Returns a Proc instance which calls the specified method on the filter
    # value object
    # @param method [Method, Proc, Symbol] the method (Method/Proc arguments are
    #   returned as-is)
    # @return [Proc] the Proc instance
    def matcher_proc(method)
      # Return Method/Proc arguments unchanged
      return method if method.is_a?(Method) || method.is_a?(Proc)
      # Otherwise return a Proc which invokes method on the filter values
      proc { |value| values.send(method, value) }
    end
  end
end
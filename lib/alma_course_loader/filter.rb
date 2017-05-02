module AlmaCourseLoader
  # Implements a filter with a call() method accepting a year, course and cohort
  # and returning true if the course should be processed, false otherwise.
  class Filter
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

    # Initialises a new Filter instance
    # @param values [Object] the value or collection to match against
    # @param mode [Symbol] the filter comparison mode
    #   :include - the filter returns true if value matches the filter values
    #   :exclude - the filter returns false if value matches the filter values
    # @param extractor [Proc, Method]  a block accepting a year, course and
    #   cohort and returning the value used in filter matching.
    #   This may be also passed as a code block.
    # @return [void]
    def initialize(values = nil, mode = :include, extractor = nil, &block)
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
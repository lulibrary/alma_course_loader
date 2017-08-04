require 'clamp'
require 'dotenv'

module AlmaCourseLoader
  # The abstract base class for course loader command line processing
  # @abstract Loader implementations should subclass this class and implement
  #   the #extractors, #reader and #time_period methods
  class CLI < Clamp::Command
    # Exit codes
    EXIT_OK = 0

    # Clamp command-line options
    option %w[-d --delete], :flag, 'generate a course delete file'
    option %w[-e --env-file], 'ENV_FILE', 'environment definitions file'
    option %w[-f --filter], 'FILTER',
           'filter condition: [field][+|-]value', multivalued: true do |value|
      Filter.parse(value, extractors)
    end
    option %w[-l --log-file], 'LOG_FILE', 'the activity log file'
    option %w[-L --log-level], 'LOG_LEVEL',
           'the log level (fatal|error|warn|info|debug)' do |value|
      { 'debug' => Logger::DEBUG,
        'error' => Logger::ERROR,
        'fatal' => Logger::FATAL,
        'info' => Logger::INFO,
        'warn' => Logger::WARN
      }[value.downcase] || Logger::ERROR
    end
    option %w[-o --out-file], 'OUT_FILE', 'the output file'
    option %w[-r --rollover], :flag, 'generate a course rollover file'
    option %w[-t --time-period], 'PERIOD',
           'the academic year (2016 etc.)', multivalued: true do |value|
      time_period(value)
    end
    option %w[-T --current-time-period], 'CURRENT_PERIOD',
           'the current academic year' do |value|
      time_period(value)
    end

    # Displays an error message and exits
    # @param msg [String, nil] the error message
    # @param code [Integer] the exit code - do not exit if nil
    # @return [void]
    def error(msg = nil, code = nil)
      STDERR.puts(msg) if msg
      exit(code) if code
    end

    # Returns a hash of named field value extractors
    # @abstract Subclasses must implement this method
    # @return [Hash<String|Symbol, Method|Proc>] the field extractors
    def extractors
      raise NotImplementedError
    end

    # Clamp entry point - executes the command
    # @return [void]
    def execute
      op = if rollover?
             :rollover
           elsif delete?
             :delete
           else
             :update
           end
      Dotenv.load(env_file) unless env_file.nil? || env_file.empty?
      AlmaCourseLoader::Writer.write(out_file, op, reader)
      exit(EXIT_OK)
    end

    # Creates a Logger instance
    def logger
      return nil unless log_file
      logger = Logger.new(log_file)
      logger.level = log_level
      logger
    end

    # Creates a Reader instance to retrieve course data
    # @abstract Subclasses must implement this method.
    #   Filters are defined in the filter_list array:
    #     MyReader.new(..., filters: filter_list)
    # @return [AlmaCourseLoader::Reader] a subclass of Reader
    def reader
      raise NotImplementedError
    end

    # Parses a time period string and returns an appropriate representation
    # @abstract Subclasses may implement this method
    # @param time_period_s [String] the string representation of the time period
    # @return [Object] the subclass-specific representation of the time period
    def time_period(time_period_s)
      time_period_s
    end
  end
end
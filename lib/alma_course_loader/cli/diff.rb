require 'clamp'
require 'logger'

module AlmaCourseLoader
  module CLI
    # Implements the course_loader_diff command-line interface
    class Diff < Clamp::Command
      # Exit codes
      EXIT_OK = 0
      # Log file alignment for multi-line entries
      LOG_SPACE = '                     '.freeze
      private_constant :LOG_SPACE
      # Log file timestamp
      LOG_TIME = '%Y-%m-%d %H:%M:%S: '.freeze

      option %w[-c --create], 'FILE', 'write new courses to FILE'
      option %w[-d --delete], 'FILE', 'write deleted courses to FILE'
      option %w[-l --log], 'FILE', 'log activity to FILE',
             attribute_name: :log_file
      option %w[-r --rollover], :flag,
             'create courses with rollover if rollover course/section is given'
      option %w[-u --update], 'FILE', 'write updated courses to FILE'
      option %w[-v --verbose], :flag, 'enable verbose logging'
      parameter 'OLD', 'the old course loader file', attribute_name: :old_file
      parameter 'NEW', 'the new course loader file', attribute_name: :new_file

      # Clamp entry point - executes the command
      def execute
        filename = log_filename
        @logger = logger(filename)
        ::AlmaCourseLoader::Diff.diff(old_file, new_file,
                                      create: create, delete: delete,
                                      rollover: rollover?,
                                      update: update) do |old, new, op, opts|
          log(old, new, op, opts) if @logger
        end
        @logger.close if @logger && filename
        exit(EXIT_OK)
      end

      # Logs a course update operation
      # @param old [String] the course entry from the old file
      # @param new [String] the course entry from the new file
      # @param op [Symbol] the course operation (:create|:delete|:update)
      # @param opts [Hash<Symbol, Object>] the diff options
      # @return [void]
      def log(old, new, op, opts)
        fields = log_course_fields(old, new, op, opts)
        course = "#{fields[0]}:#{fields[2]}"
        @logger.info("#{op.to_s.capitalize} #{course}\n")
        return unless verbose?
        @logger.debug("#{old.nil? ? '' : '< '}#{old}\n") if old
        @logger.debug("#{new.nil? ? '' : '> '}#{new}\n") if new
      end

      # Returns the course entry fields
      # @param old [String] the course entry from the old file
      # @param new [String] the course entry from the new file
      # @param op [Symbol] the course operation (:create|:delete|:update)
      # @param opts [Hash<Symbol, Object>] the diff options
      def log_course_fields(old, new, op, opts)
        op == :delete ? old.split("\t") : new.split("\t")
      end

      # Returns the command-line log filename or nil to force logging to STDOUT
      # @return [String, nil] the log filename
      def log_filename
        log_file.nil? || log_file.empty? || log_file == '-' ? nil : log_file
      end

      # Returns a Logger instance
      # @param filename [String, nil] the log filename, or nil to log to STDOUT
      # @return [Logger] the logger
      def logger(filename = nil)
        logger = Logger.new(filename || STDOUT)
        logger.level = verbose? ? Logger::DEBUG : Logger::INFO
        logger.formatter = proc do |severity, datetime, _prog_name, msg|
          time_s = severity == 'DEBUG' ? LOG_SPACE : datetime.strftime(LOG_TIME)
          "#{time_s}#{msg}"
        end
        logger
      end
    end
  end
end
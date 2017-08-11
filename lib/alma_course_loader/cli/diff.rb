require 'clamp'
require 'logger'

module AlmaCourseLoader
  module CLI
    class Diff < Clamp::Command
      # Exit codes
      EXIT_OK = 0

      option %w[-d --delete], 'DELETIONS-FILE',
             'the output file for deleted courses'
      option %w[-l --log], 'LOG-FILE', 'the log file', attribute_name: :log_file
      option %w[-u --update], 'UPDATES-FILE',
             'the output file for new and updated courses'
      option %w[-v --verbose], :flag, 'enable verbose logging'
      parameter 'OLD', 'the old course loader file', attribute_name: :old_file
      parameter 'NEW', 'the new course loader file', attribute_name: :new_file

      def execute
        log_file = nil if log_file && (log_file.empty? || log_file == '-')
        @logger = logger
        ::AlmaCourseLoader::Diff.diff(old_file, new_file,
                  delete: delete, update: update) do |old, new, op|
          log(old, new, op) if @logger
        end
        @logger.close if @logger && log_file
        exit(EXIT_OK)
      end

      def log(old, new, op)
        fields = if op == :new
                   new.split("\t")
                 else
                   old.split("\t")
                 end
        course = "#{fields[0]}:#{fields[2]}"
        @logger.info("#{op.to_s.capitalize} #{course}\n")
        return unless verbose?
        @logger.debug("#{old.nil? ? '' : '< '}#{old}\n") if old
        @logger.debug("#{new.nil? ? '' : '> '}#{new}\n") if new
      end

      def logger
        logger = Logger.new(log_file || STDOUT)
        logger.level = verbose? ? Logger::DEBUG : Logger::INFO
        logger.formatter = proc do |severity, datetime, progname, msg|
          timestamp = if severity == 'DEBUG'
                        '                     '
                      else
                        datetime.strftime('%Y-%m-%d %H:%M:%S: ')
                      end
          "#{timestamp}#{msg}"
        end
        logger
      end
    end
  end
end
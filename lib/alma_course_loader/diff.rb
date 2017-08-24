require 'logger'

module AlmaCourseLoader
  # Exception raised by the diff block to ignore the current course
  class SkipCourse < StandardError; end

  # Compares two course loader files and outputs separate files of new, deleted
  # and updated courses
  class Diff
    # Course loader operations
    OPS = %i[create delete update].freeze

    class << self
      # Reports differences between old and new course loader files
      # @param old_file [String] the old course loader filename
      # @param new_file [String] the new course loader filename
      # @param opts [Hash] the diff options
      # @option opts [IO] :create the new courses file
      # @option opts [IO] :delete the deleted courses file
      # @option opts [Boolean] :rollover if true, create new courses as
      #   rollovers when rollover course/section are present
      # @option opts [IO] :update the updated courses file
      # @yield [old_line, new_line, op, opts] passes course loader lines,
      #   operation (:create|:delete|:update) and diff options to the block; the
      #   block is only called for differences between files
      # @yieldparam old_line [String] the old course loader line
      # @yieldparam new_line [String] the new course loader line
      # @yieldparam op [Symbol] the operation (:create|:delete|:update)
      # @yieldparam opts [Hash] the diff options
      # @return [void]
      def diff(old_file = nil, new_file = nil, **opts, &block)
        # Read the course loader data from the old and new files
        old = read(old_file)
        new = read(new_file)
        # Create the creations, deletions and updates output files
        files = open_output_files(opts)
        # Perform the diff
        process(old, new, files, opts, &block)
      ensure
        close_output_files(files)
      end

      private

      # Returns true if the course entry has rollover course/section, else false
      # @param fields [Array<String>] the course loader fields
      # @return [Boolean] true if rollover course/section are set, else false
      def can_rollover?(fields)
        # Rollover requires course code and section
        return false if fields[29].nil? || fields[29].empty?
        return false if fields[30].nil? || fields[30].empty?
        true
      end

      # Closes output files
      # @param files [Hash<Symbol, IO>] the output files
      # @return [void]
      def close_output_files(files = nil)
        files.values.each(&:close) if files
      end

      # Formats the course loader line for the specified operation
      # @param line [String] the course loader line
      # @param op [Symbol] the operation (:create|:delete|:update)
      # @param opts [Hash<Symbol, Object>] the diff options
      # @return [String] the course loader line with the specified operation
      def format(line, op, opts = {})
        # Format the line (rollover code/section are never needed)
        line = line.split("\t")
        if op == :create && opts[:rollover] && can_rollover?(line)
          line[28] = 'ROLLOVER' # Rollover code/section already present
        elsif op == :delete
          line[28..30] = ['DELETE', '', ''] # Rollover code/section not needed
        else # op is either :create without rollover or :update
          line[28..30] = ['', '', ''] # Update, rollover code/section not needed
        end
        # Return the formatted line
        line.join("\t")
      end

      # Returns the key for the course loader data hash
      # @param fields [Array<String>] the course loader entry fields
      # @return [String] the key for the course loader data hash
      def key(fields)
        # course-code:section-id
        "#{fields[0]}:#{fields[2]}"
      end

      # Creates an output file
      # @param file [IO, String] the output file instance or filename
      # @param mode [String] the output file mode
      # @return [IO] the output file
      def open(file, mode = 'w')
        return file if file.nil? || file.is_a?(IO)
        raise ArgumentError('IO or filename expected') unless file.is_a?(String)
        File.open(file, mode)
      end

      # Creates output files
      # @param opts [Hash] the diff options
      # @return [Hash<Symbol, IO>] the output files, indexed by operation
      #   (:create|:delete|:update)
      def open_output_files(opts)
        files = {}
        OPS.each { |op| files[op] = open(opts[op]) }
        files
      end

      # Returns the diff operation
      # @param old_line [String] the old course loader line
      # @param new_line [String] the new course loader line
      # @return [Symbol, nil] the operation (:create|:delete|:update) or nil if
      #   there are no changes
      def operation(old_line = nil, new_line = nil)
        return nil if old_line == new_line
        return :create if old_line.nil?
        return :delete if new_line.nil?
        :update
      end

      # Process the input files
      # @param old [Hash<String, String>] the old course loader data
      # @param new [Hash<String, String>] the new course loader data
      # @param files [Hash<Symbol, IO>] the output files, indexed by operation
      #   (:create|:delete|:update)
      # @param opts [Hash] the diff options
      # @return [void]
      def process(old, new, files = nil, opts = {}, &block)
        # Handle deletions and updates to the old file
        old.each do |course, line|
          write(line, new[course], files, opts, &block)
        end
        # Handle new additions to the old file
        new.each do |course, line|
          write(nil, line, files, opts, &block) unless old.key?(course)
        end
      end

      # Returns the course loader file data as a hash: { course => loader line }
      # @param filename [String] the course loader filename
      # @return [Hash<String, String>] the course loader data
      def read(filename)
        result = {}
        File.readlines(filename).each do |line|
          line.chomp!
          fields = line.split("\t")
          result[key(fields)] = line
        end
        result
      end

      # Write the diff result to the appropriate output file
      # @param old_line [String] the old course loader line
      # @param new_line [String] the new course loader line
      # @param files [Hash<Symbol, IO>] the output files, indexed by operation
      #   (:create|:delete|:update)
      # @param opts [Hash] the diff options
      # @return [void]
      def write(old_line = nil, new_line = nil, files = nil, opts = {})
        # Determine the diff operation
        op = operation(old_line, new_line)
        return if op.nil?
        # Call the block
        yield(old_line, new_line, op, opts) if block_given?
        # Write the line to the update file
        line = op == :delete ? old_line : new_line
        files[op].write("#{format(line, op, opts)}\n") if files[op]
      rescue SkipCourse
        # The block requested that this course is skipped
      end
    end
  end
end
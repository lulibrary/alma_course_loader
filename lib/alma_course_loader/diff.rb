module AlmaCourseLoader
  # Compares two course loader files and outputs a file of deletions and a file
  # of updates
  class Diff
    class << self
      # Reports differences between old and new course loader files
      # @param old_file [String] the old course loader filename
      # @param new_file [String] the new course loader filename
      # @param delete [IO] the deletions file
      # @param update [IO] the updates file
      # @yield [old_line, new_line, op] passes the course loader lines and
      #   operation (:delete|:new|:update) to the block
      # @yieldparam old_line [String] the old course loader line
      # @yieldparam new_line [String] the new course loader line
      # @yieldparam op [Symbol] the operation (:delete|:new|:update)
      # @return [void]
      def diff(old_file = nil, new_file = nil, delete: nil, update: nil, &block)
        # Read the course loader data from the old and new files
        old = read(old_file)
        new = read(new_file)
        # Create the deletions and updates output files
        del = open(delete)
        upd = open(update)
        # Perform the diff
        process(old, new, del, upd, &block)
      ensure
        del.close if del
        upd.close if upd
      end

      private

      # Formats the course loader line for the specified operation
      # @param line [String] the course loader line
      # @param op [Symbol] the operation (:delete|:new|:update), default :update
      # @return [String] the course loader line with the specified operation
      def format(line, op = nil)
        # Check the operation is valid
        op ||= :update
        unless %i[delete new update].include?(op)
          raise ArgumentError('Operation must be :delete or :update')
        end
        # Format the line (rollover code/section are never needed)
        line = line.split("\t")
        line[28] = op == :delete ? 'DELETE' : ''
        line[29] = ''
        line[30] = ''
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

      # Returns the diff operation
      # @param old_line [String] the old course loader line
      # @param new_line [String] the new course loader line
      # @return [Symbol, nil] the operation (:delete|:new|:update) or nil if
      #   there are no changes
      def operation(old_line = nil, new_line = nil)
        return nil if old_line == new_line
        return :new if old_line.nil?
        return :delete if new_line.nil?
        :update
      end

      # Process the input files
      # @param old [Hash<String, String>] the old course loader data
      # @param new [Hash<String, String>] the new course loader data
      # @param del [IO] the deletions output file
      # @param upd [IO] the updates output file
      # @yield [old_line, new_line, op] passes the course loader lines and
      #   operation (:delete|:new|:update) to the block
      # @yieldparam old_line [String] the old course loader line
      # @yieldparam new_line [String] the new course loader line
      # @yieldparam op [Symbol] the operation (:delete|:new|:update)
      # @return [void]
      def process(old, new, del = nil, upd = nil, &block)
        # Handle deletions and updates to the old file
        old.each do |course, line|
          write(line, new[course], delete: del, update: upd, &block)
        end
        # Handle new additions to the old file
        new.each do |course, line|
          write(nil, line, update: upd, &block) unless old.key?(course)
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
      # @param delete [IO] the deletions file
      # @param update [IO] the updates file
      # @yield [old_line, new_line, op] passes the course loader lines and
      #   operation (:new|:update) to the block
      # @yieldparam old_line [String] the old course loader line
      # @yieldparam new_line [String] the new course loader line
      # @yieldparam op [Symbol] the operation (:new|:update)
      # @return [void]
      def write(old_line = nil, new_line = nil, delete: nil, update: nil)
        # Determine the diff operation
        op = operation(old_line, new_line)
        return if op.nil?
        # Call the block
        yield(old_line, new_line, op) if block_given?
        # Write the line to the update file
        if op == :delete
          delete.write("#{format(old_line, op)}\n") unless delete.nil?
        else
          update.write("#{format(new_line, op)}\n") unless update.nil?
        end
      end
    end
  end
end
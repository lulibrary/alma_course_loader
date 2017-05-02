require 'alma_course_loader/version'

module AlmaCourseLoader
  # The abstract base class for course readers.
  #
  # A course reader is responsible for reading course data from a data source
  #   and iterating over each course element. A course element is either the
  #   course itself or, if the course is divided into cohorts, a single cohort
  #   of the course.
  #
  # It is expected that courses are retrieved by year, and the iterators accept
  #   a list of years for which courses are required. The implementation and
  #   type of years, courses and cohorts is deferred to the subclasses.
  #
  # Filters may be defined which determine whether a single course element is
  #   processed or ignored. The course element must pass all filters before it
  #   is processed.
  #
  # The years and filters controlling course element iteration can be passed
  #   to the constructor, which defines defaults for subsequent iterators, or to
  #   the #each method, which defines the criteria for that iteration. When
  #   creating a reader which will be passed to a writer, always define the
  #   iterator criteria in the reader constructor, as the writer uses the
  #   default iterator.
  #
  # There are two classes of iterators. The first invokes its block with the
  #   course details: yield(year, course, cohort, instructors)
  # The second, used by the Writer class, invokes its block with an array of
  #   data suitable for writing as a row in a course loader CSV file: yield(row)
  #
  # @abstract Subclasses must implement the following methods:
  #   #courses
  #     returns a list of course objects
  #   #course_cohorts(course)
  #     returns a list of cohorts for the course or nil if cohorts are not used
  #   #current_academic_year
  #     returns the current academic year
  #   #instructors(year, course, cohort)
  #     returns a list of instructors for the course
  #   #row_data(array, year, course, cohort, instructors)
  #     configures an array of formatted course information suitable for writing
  #     to an Alma course loader CSV file
  #
  # @example Create course filters
  #   # Define extractors to retrieve values from a course element for matching
  #   # Extractors are called with the year, course and cohort arguments
  #   get_code = proc { |year, course, cohort| course.code }
  #   get_title = proc { |year, course, cohort| course.title }
  #
  #   # Define a list of course codes and a regular expression matching titles
  #   codes = ['COMPSCI101', 'PHYSICS101', 'MAGIC101']
  #   titles = Regexp.compile('dissertation|(extended|ma) essay|test', true)
  #
  #   # Define a filter which passes only the specified course codes
  #   include_codes = AlmaCourseLoader::Filter.new(codes, :include, get_code)
  #
  #   # Define a filter which passes all codes except those specified
  #   exclude_codes = AlmaCourseLoader::Filter.new(codes, :exclude, get_code)
  #
  #   # Define a filter which passes all titles matching the regular expression
  #   include_titles = AlmaCourseLoader::Filter.new(titles, :include, get_title)
  #
  #   # Define a filter which passes all titles except those matching the regexp
  #   exclude_titles = AlmaCourseLoader::Filter.new(titles, :exclude, get_title)
  #
  # @example Create a reader with default selection criteria
  #   # Filters are passed in an array, course elements must pass all filters
  #   reader = Reader.new(2016, 2017, filters: [exclude_codes, include_titles])
  #
  # @example Iterate course elements using default selection criteria
  #   reader.each { |year, course, cohort, instructors| ... }
  #
  # @example Iterate course elements using specific selection criteria
  #   # Use an empty array to override filters. filters: nil will use the
  #   # default filters.
  #   reader.each(2012, filters: []) { |year, course, cohort, instructors| ... }
  #
  # @example Iterate course CSV rows
  #   reader.each_row { |row_array| ... }
  #   reader.each_row(2012, filters: []) { |row_array| ... }
  #
  class Reader
    # Initialises a new Reader instance
    # Positional parameters are the default years to iterate over
    # @param current_year [Object] the current academic year
    # @param filters [Array<AlmaCourseLoader::Filter>] default course filters
    def initialize(*years, current_year: nil, filters: nil)
      @current_academic_year = current_year || current_academic_year
      @filters = filters
      @years = years.nil? || years.empty? ? [@current_academic_year] : years
    end

    # Iterate over the courses for specified years. Only courses which pass
    # the filters are passed to the block.
    # Positional parameters are years
    # @param filters [Array<AlmaCourseLoader::Filter>] course filters
    # @return [void]
    # @yield [year, course, cohort, year, instructors] Passes the course to the
    #   block
    # @yieldparam year [Object] the course year
    # @yieldparam course [Object] the course
    # @yieldparam cohort [Object] the course cohort
    # @yieldparam instructors [Array<Object>] the course instructors
    def each(*years, filters: nil, &block)
      # Process courses for each year
      years = @years if years.nil? || years.empty?
      years.each { |year| each_course_in_year(year, filters: filters, &block) }
      nil
    end

    # Iterates over the cohorts in a course, or just the course itself if
    # cohort processing is disabled. Only courses/cohorts which pass the filters
    # are passed to the block.
    # @param year [Object] the course year
    # @param course [Object] the course
    # @param filters [Array<AlmaCourseLoader::Filter>] course filters
    # @return [void]
    # @yield [year, course, cohort, year, instructors] Passes the course to the
    #   block
    # @yieldparam year [Object] the course year
    # @yieldparam course [Object] the course
    # @yieldparam cohort [Object] the course cohort
    # @yieldparam instructors [Array<Object>] the course instructors
    def each_cohort_in_course(year, course, filters: nil, &block)
      cohorts = course_cohorts(year, course)
      if cohorts.nil?
        # Process the course
        process_course(year, course, nil, filters, &block)
      else
        cohorts.each do |cohort|
          # Process each cohort of the course
          process_course(year, course, cohort, filters, &block)
        end
      end
    end

    # Iterates over the cohorts in a course, or just the course itself if
    # cohort processing is disabled. Only courses/cohorts which pass the filters
    # are passed to the block.
    # @param year [Object] the course year
    # @param course [Object] the course
    # @param filters [Array<AlmaCourseLoader::Filter>] course filters
    # @return [void]
    # @yield [row] Passes the course to the block
    # @yieldparam row [Array<String>] the course as a CSV row (array)
    def each_cohort_in_course_row(year, course, filters: nil, &block)
      each_cohort_in_course(year, course, filters: filters) do |*args|
        row(*args, &block)
      end
    end

    # Iterate over the courses for the specified year. Only courses which pass
    # the filters are passed to the block.
    # @param year [Object] the year
    # @param filters [Array<AlmaCourseLoader::Filter>] filters selecting courses
    # @return [void]
    # @yield [year, course, cohort, year, instructors] Passes the course to the
    #   block
    # @yieldparam year [Object] the course year
    # @yieldparam course [Object] the course
    # @yieldparam cohort [Object] the course cohort
    # @yieldparam instructors [Array<Object>] the course instructors
    def each_course_in_year(year, filters: nil, &block)
      # Simplify the test for filter existence
      filters ||= @filters
      filters = nil if filters.is_a?(Array) && filters.empty?
      # Get all courses for the year
      courses(year).each do |course|
        each_cohort_in_course(year, course, filters: filters, &block)
      end
      nil
    end

    # Iterate over the courses for the specified year. Only courses which pass
    # the filters are passed to the block.
    # @param year [Object] the year
    # @param filters [Array<AlmaCourseLoader::Filter>] course filters
    # @return [void]
    # @yield [row] Passes the course to the block
    # @yieldparam row [Array<String>] the course as a CSV row (array)
    def each_course_in_year_row(year, filters: nil, &block)
      each_course_in_year(year, filters: filters) { |*args| row(*args, &block) }
    end

    # Iterate over the courses for specified years. Only courses which pass
    # the filters are passed to the block.
    # Positional parameters are years
    # @param filters [Array<AlmaCourseLoader::Filter>] course filters
    # @return [void]
    # @yield [row] Passes the course to the block
    # @yieldparam row [Array<String>] the course as a CSV row (array)
    def each_row(*years, filters: nil, &block)
      each(*years, filters: filters) { |*args| row(*args, &block) }
    end

    protected

    # Returns a list of courses for the specified year
    # @abstract Subclasses must implement this method.
    # @param year [Object] the course year
    # @return [Array<Object>] the courses for the year
    def courses(year)
      []
    end

    # Returns a list of cohorts for the specified course
    # @abstract Subclasses should implement this method. If courses are not
    #   divided into cohorts, this method must return nil.
    # @param course [Object] the course
    # @return [Array<Object>, nil] the cohorts for the course, or nil to disable
    #   cohort processing
    def course_cohorts(year, course)
      nil
    end

    # Returns the current academic year
    # @abstract Subclasses should implement this method
    # @return [Object] the current academic year
    def current_academic_year
      nil
    end

    # Applies filters to the course/cohort to determine whether to process
    # @param year [Object] the course year
    # @param course [Object] the course
    # @param cohort [Object] the course cohort
    # @return [Boolean] true if the course is to be processed, false if not
    def filter(year, course, cohort, filters)
      # Return true if no filters are specified
      return true if filters.nil? || filters.empty?
      # Return false if any of the filters returns false
      filters.each { |f| return false unless f.call(year, course, cohort) }
      # At this point all filters returned true
      true
    end

    # Returns a list of instructors for the course/cohort
    # @abstract Subclasses should implement this method
    # @param year [Object] the course year
    # @param course [Object] the course
    # @param cohort [Object] the course cohort
    # @return [Array<Object>] the course instructors
    def instructors(year, course, cohort)
      []
    end

    # Filters and processes a course
    # @param year [Object] the course year
    # @param course [Object] the course
    # @param cohort [Object] the LUSI course cohort
    # @param filters [Array<AlmaCourseLoader::Filter>] the course filters
    # @return [Boolean] true if the course was processed, false otherwise
    # @yield Passes the course to the block
    # @yieldparam year [Object] the course year
    # @yieldparam course [Object] the course
    # @yieldparam cohort [Object] the course cohort
    # @yieldparam instructors [Array<Object>] the course instructors
    def process_course(year, course, cohort = nil, filters = nil)
      # The course must pass all filters
      return false unless filter(year, course, cohort, filters)
      # Get the course instructors
      course_instructors = instructors(year, course, cohort)
      # Pass the details to the block
      yield(year, course, cohort, course_instructors) if block_given?
      # Indicate that the course was processed
      true
    end

    # Returns a CSV row (array) for a specific course/cohort
    # @param year [Object] the course year
    # @param course [Object] the course
    # @param cohort [Object] the course cohort
    # @param instructors [Array<Object>] the
    #   course instructor enrolments
    # @yield Passes the CSV row array to the block
    # @yieldparam row [Array<String>] the CSV row array
    def row(year = nil, course = nil, cohort = nil, instructors = nil)
      # Create and populate the CSV row
      data = Array.new(31)
      row_data(data, year, course, cohort, instructors)
      # Pass the row to the block
      yield(data) if block_given?
      # Return the row
      data
    end

    # Populates the CSV row (array) for a specific course/cohort
    # @abstract Subclasses must implement this method
    # @param data [Array<String>] the CSV row (array)
    # @param year [Object] the course year
    # @param course [Object] the course
    # @param cohort [Object] the course cohort
    # @param instructors [Array<Object>] the course instructors
    def row_data(data, year, course, cohort, instructors)
      data
    end
  end
end
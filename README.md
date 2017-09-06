# AlmaCourseLoader

This gem provides a simple framework for generating Alma course loader files.
It provides a `Reader` class which serves as a basis for iterating over courses
from some data source, and a `Writer` class which uses the `Reader` to generate
a course loader file.

A command-line script `course_loader_diff` is also provided for comparing two
course loader files and generating further course loader files containing the
appropiate delete/update operations. 

The implementation of classes and command-line scripts to generate course loader
files from specific data sources is left to clients of this gem.

## Installation

Add this line to your application's Gemfile:

```ruby
gem 'alma_course_loader'
```

And then execute:

    $ bundle

Or install it yourself as:

    $ gem install alma_course_loader

## Configuring Course Loading

1. Write a command-line script to create a course loader file from your course
manager or other data source. This gem provides helper classes to assist with
this - see *Writing a Course Loader* below.

2. Schedule this script to run at regular intervals.

3. Schedule the script `course_loader_diff` to run after the course loader
script to generate the deletions and updates to be processed by Alma.

4. Schedule Alma course loader jobs to run after `course_loader_diff` to
process the generated files.

An example using `cron` to schedule a daily course update using the fictitious
course loader script `load_courses_from_cms` might be:
```bash
# File locations
dir_data=/home/alma/course/data
dir_delete=/home/alma/course/delete
dir_update=/home/alma/course/update

# Use dates as filenames
today=$(date +%Y%m%d)
yday=$(date -d "-1 day" +%Y%m%d)

# Files
data_today=${dir_data}/$today
data_yday=${dir_data}/$yday 
del=${dir_delete}/$today
log=/var/log/course/$today
upd=${dir_update}/$today

# Load courses from course management system daily at 1am
00 01 * * * /opt/bin/load_courses_from_cms --out=$data_today

# Write changes to Alma course loader files, log verbosely to $log
00 04 * * * /opt/bin/course_loader_diff --delete=$del --log=$log --update=$upd --verbose $data_yday $data_today
```

## Command-line Scripts

### course_loader_diff

This script accepts two course loader files (the "current" or most-recently
created file, and the "previous" file preceding the current file) and outputs
the course entries which differ between the files. These files can be loaded
into Alma to perform the required changes.

The differences are written to three files:

* `create-file` contains new courses (those in `current-file` which are not in
  `previous-file`) - by default these are applied using the *update* method
  unless the `--rollover` flag is specified, which triggers updates using the
  *rollover* method.
  
* `delete-file` contains deleted course (those in `previous-file` which are not
  in `current-file`) - these are applied using the *delete* method.
  
* `update-file` contains courses which exist in both files but differ - these
  are applied using the *update* method.  

To allow course creation by *rollover* both input files should include the
rollover course code and section fields. If these fields are not present, all
courses will be created by *update* so associated reading lists will not be
copied.

`course_loader_diff` accepts the following command-line options:
```bash
course_loader_diff -c create-file
                   -d delete-file
                   [-h | --help]
                   [-l | --log log-file]
                   [-r | --rollover]
                   -u update-file
                   [-v | --verbose]
                   previous-file current-file
```

##### `-c create-file | --create=create-file`

The output file of newly-created courses.

##### `-d delete-file | --delete=delete-file`

The output file of deleted courses.

##### `-h | --help`

Displays a help page for the command-line interface.

##### `-l log-file | --log=log-file`

The activity log file (defaults to stdout).

##### `-r | --rollover`

Causes newly-created courses to be created using the *rollover* method rather
than the *update* method as long as the course entry contains both the rollover
course and section fields. Courses which omit either of the rollover course
fields will be created using the *update* method.

##### `-u update-file | --update=update-file`

The output file of updated courses.

##### `-v | --verbose`

Causes the course loader entries to be included in the activity log, prefixed by
'<' (`previous-file`) and `>` (`current-file`).

##### `previous-file`

The input file from a previous course loader run, e.g. yesterday.

##### `current-file`

The input file from the latest course loader run, e.g. today.

Detailed usage is available from the command's help page:
```bash
course_loader_diff -h
```

## Writing a Course Loader

This gem provides helper classes which may help to generate Alma course loader
files from any data source. It is not necessary to use these, as long as the
output of the course loader is a valid Alma course loader file representing the
source course data.

The helper classes abstract course loader file generation into a `Reader` which
iterates over the source data, a `Filter` which selects courses for processing
and a `Writer` which generates the Alma course loader file.

### Reader

The following model is assumed:

* Courses are retrieved by year.

* Courses may optionally consist of a number of cohorts. If this is the case, a
*course element* is a single cohort of a specific course for a specific year. If
not, the course element is the course itself for a specific year.

* Course elements have one or more associated instructors.

`Reader` provides an abstract base class for iterating over course elements read
from any data source. The iterators accept a list of years for which courses are
required. The implementation details of years, courses and cohorts are deferred
to the subclasses.

#### Basic use

```ruby
# Create a reader
reader = Reader.new

# Iterate over course elements
reader.each { |year, course, cohort, instructors| ... }

# Iterate over course elements as rows of the course loader CSV file
reader.each_row { |row| ... }
```

The constructor and iterator methods accept course criteria as arguments.
Positional arguments are years for which courses are required. The `filter`
keyword argument may specify a list of filters to further refine the courses.

Course criteria passed to the constructor are used as defaults for subsequent
iterations. Criteria passed to the iterators override the defaults for that
use only.

```ruby
# Create a reader with default critria
reader = AlmaCourseLoader::Reader.new(2015, 2016, filters: [f1, f2])

# Use the default criteria:
reader.each { |year, course, cohort, instructors| ... }
reader.each_row { |row| ... }

# Override the default years but use the default filters
reader.each(2013) { |year, course, cohort, instructors| ... }

# Override the default years and cancel the default filters
#   the empty filter list is required to cancel the default filters
reader.each(2012, filters: []) { |row| ... }
```

#### Filters

##### Creating a filter

A `Filter` is an object which extracts a value from a course element and
matches it against a known value or set of values. If the match succeeds, the
filter returns `true` and the course element has *passed* the filter. If the
match fails, the filter returns `false` and the course element is rejected.

###### Constructor

To construct a filter, pass in the value(s) to be matched against, the match
criterion (whether a match is considered a success or failure) and a code
block which extracts the match value from the course element.
```ruby
# Extractor as a code block
filter = AlmaCourseLoader::Filter.new(values, criterion) { |year, course, cohort| ... }

# Extractor as a Proc
extactor = proc { |year, course, cohort| ... }
filter = AlmaCourseLoader::Filter.new(values, criterion, extractor)
```
The match values can be:
* a single value (the values must stringwise match)
* an `Array`, `Hash` or `Set` (the extracted value must be in the values)
* a `Regexp` (the extracted value must match the regular expression)

The match criterion is either:
* `:exclude` (a match is a failure, i.e. the filter succeeds if it
excludes the extracted value)
* `:include` (a match is a success, i.e. the filter succeeds if it includes the
value)

The extractor is a `Proc` or code block which accepts the year, course and
cohort and returns a value to be matched against the filter's values.

###### Parsing

A `Filter` can also be created by parsing a filter specification string:

```ruby
filter = Filter.parse(filter_s, extractors)
```

where `filter_s` is the filter specification string (see *Filter specification
strings* below) and `extractors` is a `Hash` mapping `Symbol` (extractor names)
to extractor `Proc` instances.

##### Filter specification strings
 
The general form of a filter specification string is:

```[!][field [op ]]value```

where:
 * `!` negates the condition
 * `field` is the name of a defined field extractor,
 * `op` is one of the following operators:
   * `<`, `<=`, `==`, `!=`, `>=`, `>` the value of field is less than (etc.)
     value
   * `~`, `!~` the value of field matches/does not match the regular expression
     value  
   * `in` the value of field is a key (if value is a hash) or a value (if value
     is any other type) in value; equivalent to value.include?(field)
   * `keyin` the value of field is a key of the value hash; equivalent
     to value.key?(field)
   * `valuein` the value of field is a value in the value hash; equivalent to
     value.value?(field)      
 * `value` is either a JSON string (which must include double-quotes around string
literal values and may specify arrays and hashes) or a regular expression
delimited by `/`.

Examples:

```ruby
# Course code must exactly match CS101
course_code == "CS101"    

# Course code must be one of CS101, CS102 or CS103
course_code in ["CS101", "CS102", "CS103"]

# Year must not be 2015 or 2016
! year in [2015, 2016]

# Course code must begin with CS
course_code ~ /^CS/
```

##### Examples 
```ruby
codes = ['COMPSCI101', 'MAGIC101']
year1_magic = /MAGIC1\d\d/

# Extractor
get_code = proc { |year, course, cohort| course.code }
extractors = { code: get_code }

# Include only the specified codes
filter = AlmaCourseLoader::Filter.new(codes, :include, get_code)
# Using a filter specification string
filter = AlmaCourseLoader::Filter.parse('code in ["COMPSCI101", "MAGIC101"]', extractors)

# Include all except the specified codes
filter = AlmaCourseLoader::Filter.new(codes, :include, get_code, true)
# Using a filter specification string
filter = AlmaCourseLoader::Filter.parse('! code in ["COMPSCI101", "MAGIC101"]')

# Include all codes matching the regular expression
filter = AlmaCourseLoader::Filter.new(year1_magic, :match, get_code)
# Using a filter specification string
filter = AlmaCourseLoader::Filter.parse('code ~ /MAGIC\d\d/', extractors)

# Include exactly the specified code
filter = AlmaCourseLoader::Filter.new('MAGIC101', :==, get_code)
# Using a filter specification string
filter = AlmaCourseLoader::Filter.parse('code == "MAGIC101"', extractors)

# Include all except the specified code
filter = AlmaCourseLoader::Filter.new('MAGIC101', :!=, get_code)
# or equivalently
filter = AlmaCourseLoader::Filter.new('MAGIC101', :==, get_code, true)
# Using a filter specification string
filter = AlmaCourseLoader::Filter.parse('code != "MAGIC101"', extractors)
# or equivalently
filter = AlmaCourseLoader::Filter.parse('! code == "MAGIC101"', extractors)

# Include all codes stringwise less than "MAGIC101"
# - note that comparison operators are called against the filter value,
#   so "code < filter-value" must be formulated as "filter-value > code"
 #  and "code > filter-value" as "filter-value < code"
filter = AlmaCourseLoader::Filter.new('MAGIC101', :>, get_code)
# Using a filter specification string
# - no need to invert the test as above, the parser handles this
filter = AlmaCourseLoader::Filter.parse('code < "MAGIC101"', extractors)
```

##### Executing a filter
Filters provide a `call` method which accepts the year, course and cohort and
returns `true` if the course passes or `false` if it's rejected.

```ruby
if filter.call(year, course, cohort)
  # The course passes, continue processing
else
  # The course is rejected
end
```

##### Using filters with readers
`Reader` constructor and iterator methods accept a list of filters:
```ruby
filter1 = AlmaCourseLoader::Filter.new(...)
filter2 = AlmaCourseLoader::Filter.new(...)
reader = Reader.new(..., filters: [filter1, filter2])
reader.each(..., filters: [filter1]) { ... }
```

Course elements must pass all filters. If any filter fails, the course element
is not passed to the iterator's code block.
 
#### Writing a custom `Reader`

A `Reader` subclass may define any implementation of course, cohort, instructor
and year and must implement the following methods: 

##### `courses(year)`
```ruby
# Returns an array of course objects for the year
def courses
  # A course may be any object defined by the implementation 
end
```

##### `course_cohorts(year, course)`
```ruby
# Returns an array of cohorts for the course, or nil if cohorts are not used
def course_cohorts(year, course)
  # A cohort may be any object defined by the implementation
end
```

##### `current_academic_year`
```ruby
# Returns the current academic year
def current_academic_year
  # A year may be any object defined by the implementation
end
```

##### `instructors(year, course, cohort)`
```ruby
# Returns an array of instructors for the given year, course and cohort
def instructors(year, course, cohort)
  # An instructor may be any object defined by the implementation
end
```

##### `row_data(data, year, course, cohort, instructors)`
```ruby
# Populates the data array for a course element row in the Alma course
# loader CSV file. The data array is pre-allocated by the caller.
def row_data(data, year, course, cohort, instructors)
  # The implementation must define the current course details
  data[0] = 'Current-year-course-code'
  # :
  data[2] = 'Current-year-section-id'

  # The implementation must define the previous year's course code/section
  # These will be ignored by the Writer unless required for rollover
  data[29] = 'Previous-year-course-code'
  data[30] = 'Previous-year-section-id'
end
```

### Writer

The `Writer` class provides a single class-level method `write` which generates
an Alma course loader file given an appropriate `Reader`:

```ruby
Writer.write(output_filename, course_loader_op, reader)
```

The `course_loader_op` is the Alma course loader operation applied to all course
elements provided by the `reader`. This may be:
* `:delete` to delete the courses in the file
* `:rollover` to implement rollover to the courses defined by the file
* `:update` to update the courses in the file

### Command Line Scripts

The `CLI::CourseLoader` class provides support for writing command-line course
loader scripts.

#### Extending CLI::CourseLoader

To implement a course loader command-line script, clients should subclass
`CLI::CourseLoader` and implement the following methods:

##### `extractors`

This method defines the field extractors available to filter specifications.
It returns a `Hash` mapping symbols (extractor names) to `Proc` instances
responsible for extracting a single field of the course data. The hash keys are
the field names used in filter specifications.

Each `Proc` instance of the form:
```ruby
proc { |year, course, cohort| # return some field value }
``` 

The following example defines the fields `course` and `year` for use in filters:
```ruby
# Field descriptions
def extractor_details
  {
    course: 'Course code',
    year: 'Course year'
  }.freeze
end

# Field definitions
def extractors
  {
    course: proc { |year, course, cohort| course.course_code },
    year: proc { |year, course, cohort| year }
  }.freeze
end
```

##### `reader`

This should return an instance of a subclass of `AlmaCourseLoader::Reader` which
returns courses from the course manager data source.

##### `time_period(time_period_s)`

This method accepts a client-specific string representation of a time period
and returns an appropriate internal object representing that time period. For
example:

```ruby
def time_period(time_period_s)
  # Accept strings such as "2017-18" but internally work with integer years
  time_period_s[0..3].to_i
end
```

#### Command-Line Usage

Course loader scripts derived from `CLI::CourseLoader` accept the following
command-line options:

```bash
course_loader [-d|--delete]
              [-e|--env=env-file]
              [-f|--filter=filter]...
              [-F|--fields]
              [-l|--log-file=log-file]
              [-L|--log-level=debug|error|fatal|info|warn]
              [-o|--out-file=output-file]
              [-r|--rollover]
              [-t|--time-period=time-period]...
```

##### `-d | --delete`

Adds the `DELETE` operation to the course loader file, causing all entries in
the file to be deleted when the file is processed by Alma.

##### `-e env-file | --env=env-file`

Specifies a file of environment variable definitions for configuration.

##### `-f filter | --filter=filter`

Specifies a filter restricting the courses to be exported. See *Filter
specification strings* for the filter syntax. This flag may be repeated to
specify multiple filters; a course must pass every filter to be included in the
export. 

##### `-F | --fields`

Lists the fields available to filters.

##### `-h | --help`

Displays a help page for the command-line interface.

##### `-l log-file | --log-file=log-file`

Specifies a file for logging course loader activity.

##### `-L log-level | --log-level=log-level`

Specifies the logging level: `fatal|error|warn|info|debug`.

##### `-o out-file | --out-file=out-file`

Specifies the output course loader file.

##### `-r | --rollover`

Adds the `ROLLOVER` operation and previous course code/section to the course
loader file, triggering Alma's course rollover processing for the specified
courses. 

##### `-t time-period | --time-period=time-period`

Specifies the course time period covered by the export. This flag may be
repeated to specify multiple time periods. 
The exact syntax and meaning of `time-period` is left to clients of this gem.

## Development

After checking out the repo, run `bin/setup` to install dependencies. Then, run `rake test` to run the tests. You can also run `bin/console` for an interactive prompt that will allow you to experiment.

To install this gem onto your local machine, run `bundle exec rake install`. To release a new version, update the version number in `version.rb`, and then run `bundle exec rake release`, which will create a git tag for the version, push git commits and tags, and push the `.gem` file to [rubygems.org](https://rubygems.org).

## Contributing

Bug reports and pull requests are welcome on GitHub at https://github.com/lulibrary/alma_course_loader. This project is intended to be a safe, welcoming space for collaboration, and contributors are expected to adhere to the [Contributor Covenant](http://contributor-covenant.org) code of conduct.


## License

The gem is available as open source under the terms of the [MIT License](http://opensource.org/licenses/MIT).
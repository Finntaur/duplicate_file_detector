require 'optparse'
require 'progress_bar'

require File.join(__dir__, 'directory')
require File.join(__dir__, 'cache')
require File.join(__dir__, 'analyzed_file')

module DFD
  class Detector
    VERSION = '1.0'.freeze

    class Options
      attr_accessor(:paths, :include_all, :recursive, :quiet, :cache, :dry_run)

      def initialize
        @paths = []
        @recursive = false
        @include_all = false
        @quiet = false
        @parser = nil
        @dry_run = false
      end

      def set(parser:)
        @parser = parser
        @parser.banner = 'Usage: dfd [OPTIONS] PATH ...'
        @parser.separator('')
        @parser.separator('Available options:')

        set_include_all_option
        set_clear_cache_option
        set_recursive_option
        set_quiet_option
        set_dry_run_option

        @parser.on_tail('-h', '--help', 'Show this help') do
          help
        end

        @parser.on_tail('-v', '--version', 'Display version') do
          version
        end

        @paths = @parser.default_argv
      end

      def help
        STDOUT.puts(@parser)
        exit
      end

      def version
        STDOUT.puts(DFD::Detector::VERSION)
        exit
      end

      private

      def set_include_all_option
        @parser.on('-a', '--all', 'Include all files') do
          @include_all = true
        end
      end

      def set_quiet_option
        @parser.on('-q', '--quiet', 'Silence all output') do
          @quiet = true
        end
      end

      def set_recursive_option
        @parser.on('-r', '--recursive', 'Recurse into subdirectories') do
          @recursive = true
        end
      end

      def set_clear_cache_option
        @parser.on('--clear-cache', 'Just clear the cache and exit, ignore all other options') do
          $STDOUT = STDOUT
          DFD::Cache.new.purge!(all: true)
          exit
        end
      end

      def set_dry_run_option
        @parser.on('-n', '--dry-run', 'Take no action on the duplicates') do
          @dry_run = true
        end
      end
    end

    # -------------------------------------------------------------------------

    def initialize(arguments = nil)
      set_options(arguments ? arguments : [])
      @directory = DFD::Directory.new
      @cache = DFD::Cache.new
    end

    def execute
      @options.help if @options.paths.empty?
      $STDOUT = ( @options.quiet ? nil : STDOUT )

      locate_files
      files_to_analyze = @directory.clone
      @cache.purge!
      $STDOUT&.puts('Loading cache ...')
      progress_bar = ($STDOUT ? ProgressBar.new(@directory.size) : nil)
      @directory.files.each do |path|
        files_to_analyze.remove(path) if @cache.cached?(path)
        progress_bar&.increment!
      end
      analyze(files_to_analyze)

      duplicates = []

      $STDOUT&.puts('Looking for duplicates ...')
      progress_bar = ($STDOUT ? ProgressBar.new(@directory.size) : nil)
      @directory.files.each do |path|
        dups = @cache.find_duplicates(path)
        duplicates << dups.sort if 1 < dups.size
        progress_bar&.increment!
      end
      duplicates.uniq!

      DFD::Handler.new(duplicates).start
    end

    private

    def analyze(directory)
      return if directory.size <= 0
      $STDOUT&.puts('Analyzing files ...')
      progress_bar = ($STDOUT ? ProgressBar.new(directory.size) : nil)
      directory.files.each do |path|
        @cache.add(DFD::AnalyzedFile.new(path))
        progress_bar&.increment!
      end
    end

    def locate_files
      $STDOUT&.puts('Indexing files ...')
      progress_bar = ($STDOUT ? ProgressBar.new(@options.paths.size) : nil)
      @options.paths.each do |path|
        @directory.add(
          path,
          recursive: (@options.recursive ? true : 1),
          include_all: @options.include_all
        )
        progress_bar&.increment!
      end
      @directory.tidy!
    end

    def set_options(arguments)
      @options = DFD::Detector::Options.new
      OptionParser.new do |parser|
        @options.set(parser: parser)
        parser.parse!
      end
    end

  end
end

# Allow direct execution.
DFD::Detector.new(ARGV).execute if __FILE__ == $0

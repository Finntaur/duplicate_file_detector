module DFD
  class DuplicateFileSet
    attr_reader(:files, :size, :sha512, :md5, :oldest, :newest)

    def initialize(files:, size:, sha512:, md5:)
      raise ArgumentError.new("Expected an Array, got #{files.inspect}") unless files.is_a?(Array)
      @files = files
      @size = size
      @sha512 = sha512
      @md5 = md5

      @oldest = @files.first
      @newest = @files.first
      @files.each do |file|
        stat = File.stat(file)
        @oldest = file if stat.birthtime < File.stat(oldest).birthtime
        @newest = file if File.stat(newest).mtime < stat.mtime
      end
    end

    def count
      @files.size
    end

    def tidy!
      @files.uniq!
      @files.sort!

      self
    end

  end
end

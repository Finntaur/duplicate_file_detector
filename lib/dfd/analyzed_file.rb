require 'digest'

module DFD
  class AnalyzedFile
    def initialize(path)
      unless File.file?(path)
        raise ArgumentError.new("Expected a path to a regular file, got #{path.inspect}")
      end

      @path       = File.absolute_path(path)
      stat        = File.stat(@path)
      @size       = stat.size
      @updated_at = stat.mtime.round
      @millis     = (stat.mtime.subsec * 1000).round
      @sha512     = Digest::SHA512.file(@path).hexdigest
      @md5        = Digest::MD5.file(@path).hexdigest
    end

    attr_reader(:path, :size, :updated_at, :millis, :sha512, :md5)
  end
end

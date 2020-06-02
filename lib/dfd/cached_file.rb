module DFD

  class CachedFile
    def initialize(data)
      @id         = data[DATABASE_COLUMNS.index('rowid')].to_i
      @path       = data[DATABASE_COLUMNS.index('path')]
      @size       = data[DATABASE_COLUMNS.index('size')].to_i
      @updated_at = Time.parse(data[DATABASE_COLUMNS.index('updated_at')])
      @millis     = data[DATABASE_COLUMNS.index('millis')].to_i
      @sha512     = data[DATABASE_COLUMNS.index('sha512')]
      @md5        = data[DATABASE_COLUMNS.index('md5')]
    end

    attr_reader(:id, :path, :size, :updated_at, :millis, :sha512, :md5)
  end

end

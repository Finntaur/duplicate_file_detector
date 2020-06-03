require 'progress_bar'
require 'sqlite3'
require 'time'

require File.join(__dir__, 'cached_file')

module DFD
  DEFAULT_DATABASE = File.join(ENV['HOME'], '.dfd.sqlite3').freeze
  DATABASE_TABLE = 'files'.freeze
  DATABASE_COLUMNS = %w(rowid path size updated_at millis sha512 md5).freeze
  DATABASE_TIMEOUT = 2000.freeze
  BATCH_SIZE = 500.freeze

  class Cache
    attr_reader(:database)

    def initialize(database = nil)
      database ||= DEFAULT_DATABASE

      # Open database connection.
      @database = SQLite3::Database.new((database))
      @database.busy_timeout = DATABASE_TIMEOUT

      # Create the database if one doesn't exist yet.
      @database.execute("
        CREATE TABLE IF NOT EXISTS #{DATABASE_TABLE} (
          updated_at DATETIME,
          millis UNSIGNED SMALLINT,
          size UNSIGNED BIGINT,
          sha512 VARCHAR(128),
          md5 VARCHAR(32),
          path TEXT
        );
        CREATE UNIQUE INDEX IF NOT EXISTS index_files_on_path ON files (path);
        CREATE INDEX IF NOT EXISTS index_files_on_sha512 ON files (sha512);
        CREATE INDEX IF NOT EXISTS index_files_on_md5 ON files (md5);
      ")
    end

    # Close the database connection.
    def close
      #@database.execute("BEGIN TRANSACTION; END; COMMIT;")
      @database.commit rescue nil
      @database.close
    end

    # Tries to insert AnalyzedFile to the cache. Existence of a previous
    # record must be done elsewhere.
    def add(analyzed_file)
      unless analyzed_file.is_a?(AnalyzedFile)
        raise ArgumentError.new("Expected AnalyzedFile, got #{analyzed_file.inspect}")
      end

      query = @database.prepare("
        INSERT INTO #{DATABASE_TABLE}
          (path, size, updated_at, millis, sha512, md5)
          VALUES (?, ?, ?, ?, ?, ?);
      ")
      @database.commit rescue nil
      query.execute(
        analyzed_file.path,
        analyzed_file.size,
        analyzed_file.updated_at.to_s,
        analyzed_file.millis,
        analyzed_file.sha512,
        analyzed_file.md5
      )
    end

    # Find all files that match the checksums and filesize of the item on
    # the row with provided absolute path.
    def find_copies(path)
      query = @database.prepare("
        SELECT #{DATABASE_COLUMNS.join(',')}
          FROM #{DATABASE_TABLE}
          WHERE path = ?
          LIMIT 1
      ")
      file = DFD::CachedFile.new(query.execute(path).first)

      query = @database.prepare("
        SELECT path
          FROM #{DATABASE_TABLE}
          WHERE size = ?
            AND sha512 = ?
            AND md5 = ?
      ")

      copies = []
      query.execute(file.size, file.sha512, file.md5).each do |copy|
        copies << copy.first
      end

      copies
    end
    alias_method(:find_duplicates, :find_copies)

    # Browse through the entire cache and remove any entries that no longer
    # exist in the filesystem, or have been touched (timestamp or size changed)
    # since last update.
    def purge!(all: false)
      if all
        $STDOUT&.puts('Wiping the cache ...')
        @database.execute("
          DELETE FROM #{DATABASE_TABLE} WHERE true;
        ")
        @database.commit rescue nil
        $STDOUT&.puts('Done!')
        return
      end

      cached_items = self.size

      # No need to purge unless the cache contains something.
      if 0 < cached_items
        $STDOUT&.puts('Purging old cache ...')
        progress_bar = ($STDOUT ? ProgressBar.new(cached_items) : nil)
        iterator = 0

        # Load rows from the database in batches. Collect garbage after each one.
        while iterator * BATCH_SIZE < cached_items do
          offset = [0, cached_items - ((iterator += 1) * BATCH_SIZE)].max
          purgeable = []

          # Inspect cached items one by one.
          @database.execute("
            SELECT #{DATABASE_COLUMNS.join(',')}
              FROM #{DATABASE_TABLE}
              ORDER BY rowid ASC
              LIMIT #{BATCH_SIZE}
              OFFSET #{offset};
          ").each do |row|
            item = DFD::CachedFile.new(row)
            purgeable << item.id.to_i unless valid?(item)
            progress_bar&.increment!
          end

          # Delete all outdated items from the cache.
          unless purgeable.empty?
            @database.execute("
              DELETE FROM #{DATABASE_TABLE} WHERE rowid IN (#{purgeable.join(',')});
            ")
            @database.commit rescue nil
          end
          GC.start
        end
      end
    end

    # Retrieve the size of the cache, i.e. how many items there are currently.
    def size
      @database.execute("SELECT COUNT(*) FROM #{DATABASE_TABLE};").first.first
    end

    # Checks whether or not the provided path has already been cached.
    def cached?(path)
      absolute_path = File.absolute_path(path)
      query = @database.prepare("
        SELECT EXISTS(SELECT 1 FROM files WHERE path = ? LIMIT 1);
      ")

      1 == query.execute(absolute_path).first.first
    end

    # Checks whether or not the provided CachedFile object is still valid
    # or should be purged. True value means that the object has not been
    # modified since last cache.
    def valid?(cached_file)
      unless cached_file.is_a?(CachedFile)
        raise ArgumentError.new("Expected a DFD::CachedFile, got #{cached_file.class}")
      end

      return false unless File.exists?(cached_file.path)

      stat = File.stat(cached_file.path)
      return false if cached_file.size != stat.size
      return false if cached_file.updated_at != stat.mtime.round
      return false if cached_file.millis != (stat.mtime.subsec * 1000).round

      true
    end

  end
end

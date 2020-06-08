require 'fileutils'
require 'os'

module DFD
  class Trasher

    MODES = %i(remove trash).freeze

    def initialize(mode:)
      raise ArgumentError.new("Unknown mode #{mode}") unless MODES.include?(mode)
      @mode = mode
      @trash_path = nil
      locate_trash if :trash == @mode
    end

    def trash(absolute_path)
      case @mode
      when :trash
        move_to_trash(absolute_path)
      when :remove
        remove(absolute_path)
      else
        raise ScriptError.new("Unsupported trasher mode '#{@mode}'")
      end
    end

    private

    def locate_trash
      if OS.mac?
        @trash_path = File.join(ENV['HOME'], '.Trash')
      elsif OS.linux?
        @trash_path = File.join(ENV['HOME'], 'Desktop', 'Trash')
        @trash_path = File.join(ENV['HOME'], '.local', 'Trash', 'files') unless File.directory?(@trash_path)
        raise ScriptError.new('Could not locate trash can.') unless File.directory?(@trash_path)
      else
        raise ScriptError.new('Trash is unsupported on this platform.')
      end
    end

    def move_to_trash(absolute_path)
      target_path = uncollide_filename(File.join(@trash_path, File.basename(absolute_path)))
      FileUtils.move(absolute_path, target_path, force: true)
    end

    def remove(absolute_path)
      File.delete(absolute_path)
    end

    def uncollide_filename(absolute_path)
      return absolute_path unless File.exists?(absolute_path)

      new_number = absolute_path.match(/\((\d+)\)(?:\.[^.]+)?$/)&.[](1).to_i + 1
      alternative_path = absolute_path.sub(/\s*(?:\(\d+\))?(\.[^.]+)?$/, " (#{new_number})\\1")

      uncollide_filename(alternative_path)
    end
  end
end

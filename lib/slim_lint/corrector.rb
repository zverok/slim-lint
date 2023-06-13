# frozen_string_literal: true

module SlimLint
  class Corrector
    attr_reader :source

    def initialize(source)
      @source = source
    end

    def edit_line(line, &block)
      lines = @source.lines
      # TODO: out of bounds
      lines[line - 1] = block.call(lines[line - 1])
      @source = lines.join
    end

    def replace(src)
      @source = src
    end
  end
end

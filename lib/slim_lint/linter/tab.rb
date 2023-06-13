# frozen_string_literal: true

module SlimLint
  # Searches for tab indentation
  class Linter::Tab < Linter
    include LinterRegistry

    MSG = 'Tab detected'

    on_start do |_sexp|
      dummy_node = Struct.new(:line)
      document.source_lines.each_with_index do |line, index|
        next unless line =~ /^( *)[\t ]*\t/

        report_lint(dummy_node.new(index + 1), MSG)

        correct_lint do |corrector|
          # TODO: Probably requires config of tab size if to be merged in the upstream
          corrector.edit_line(index + 1) { _1.gsub("\t", "  ") }
        end
      end
    end
  end
end

# frozen_string_literal: true

module SlimLint
  # This linter checks for two or more consecutive blank lines
  # and for the first blank line in file.
  class Linter::EmptyLines < Linter
    include LinterRegistry

    on_start do |_sexp|
      dummy_node = Struct.new(:line)

      was_empty = true
      removed = 0
      document.source.lines.each_with_index do |line, i|
        if line.blank?
          if was_empty
            report_lint(dummy_node.new(i + 1),
                        'Extra empty line detected')
            correct_lint { |corrector|
              # corrector has lines including "\n", so just replacing with empty line will remove it
              removed += 1
              # we need to account for already removed lines to remove the right one
              corrector.edit_line(i + 1 - removed) { '' }
            }
          end
          was_empty = true
        else
          was_empty = false
        end
      end
    end
  end
end

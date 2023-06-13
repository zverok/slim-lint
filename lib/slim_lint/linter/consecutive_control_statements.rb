# frozen_string_literal: true

module SlimLint
  # Searches for more than an allowed number of consecutive control code
  # statements that could be condensed into a :ruby filter.
  class Linter::ConsecutiveControlStatements < Linter
    include LinterRegistry

    on [:multi] do |sexp|
      Utils.for_consecutive_items(sexp,
                                  method(:flat_control_statement?),
                                  config['max_consecutive'] + 1) do |group|
        report_lint(group.first,
                    "#{group.count} consecutive control statements can be " \
                    'merged into a single `ruby:` filter')

        # FIXME: It counts statements wrongly (misses the last one) if there is an empty line after
        # the last one.
        correct_lint do |corrector|
          lines = corrector.source.lines
          replaced = lines[group.first.line-1..group.last.line-1]
          indent = replaced.first[/^ */].size
          src = lines[0...group.first.line-1].join +
            (' ' * indent + "ruby:\n") +
              replaced.map { _1.sub(/^( *)- ?/, '\\1  ') }.join + # TODO: is "- " the only way? configurable indent
              lines[group.last.line..].join
          corrector.replace(src)
        end
      end
    end

    private

    def flat_control_statement?(sexp)
      sexp.match?([:slim, :control]) &&
        sexp[3] == [:multi, [:newline]]
    end
  end
end

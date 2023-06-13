# frozen_string_literal: true

module SlimLint
  # Searches for control statements with only comments.
  class Linter::CommentControlStatement < Linter
    include LinterRegistry

    on [:slim, :control] do |sexp|
      _, _, code = sexp
      next unless code[/\A\s*#/]

      comment = code[/\A\s*#(.*\z)/, 1]

      next if comment =~ /^\s*rubocop:\w+/
      next if comment =~ /^\s*Template Dependency:/

      report_lint(sexp,
                  "Slim code comments (`/#{comment}`) are preferred over " \
                  "control statement comments (`-##{comment}`)")

      # FIXME: might be other control statements than `-# foo`?..
      correct_lint do |corrector|
        corrector.edit_line(sexp.line) { _1.sub(/^(\s*)-(\s*)\#/, '\\1/') }
      end
    end
  end
end

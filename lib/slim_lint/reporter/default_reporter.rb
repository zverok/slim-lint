# frozen_string_literal: true

module SlimLint
  # Outputs lints in a simple format with the filename, line number, and lint
  # message.
  class Reporter::DefaultReporter < Reporter
    def display_report(report)
      sorted_lints = report.lints.sort_by { |l| [l.filename, l.line] }

      sorted_lints.each do |lint|
        print_location(lint)
        print_type(lint)
        print_message(lint)
      end

      print_stats(sorted_lints)
    end

    private

    def print_location(lint)
      log.info lint.filename, false
      log.log ':', false
      log.bold lint.line, false
    end

    def print_type(lint)
      if lint.error?
        log.error ' [E] ', false
      else
        log.warning ' [W] ', false
      end
    end

    def print_message(lint)
      if lint.linter
        log.success("#{lint.linter.name}: ", false)
      end

      log.log lint.message
    end

    def print_stats(lints)
      # TODO: Time of running
      # TODO: Configurable
      # TODO: Total number of files processed
      log.log ''
      log.log "#{lints.count} problems found in #{lints.group_by(&:filename).count} files, "\
              "#{lints.count(&:error?)} errors, #{lints.reject(&:error?).count} warnings."
    end
  end
end

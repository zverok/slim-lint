# frozen_string_literal: true

require 'slim_lint/ruby_extractor'
require 'slim_lint/ruby_extract_engine'
require 'rubocop'

module SlimLint
  # Runs RuboCop on Ruby code extracted from Slim templates.
  class Linter::RuboCop < Linter
    include LinterRegistry

    on_start do |_sexp|
      processed_sexp = SlimLint::RubyExtractEngine.new.call(document.source)

      extractor = SlimLint::RubyExtractor.new
      extracted_source = extractor.extract(processed_sexp)

      next if extracted_source.source.empty?

      # puts extracted_source.source
      find_lints(extracted_source.source, extracted_source.source_map)

      correct_lint do |corrector|
        original_lines = extracted_source.source.lines
        new_lines = @rubocop_output.lines
        source_lines = corrector.source.lines

        # Rubocop did some relayouting. We are helpless to find the correspondences to replace them
        # TODO: Actually, we can try to align small chunks of code by co-arranging _slim_lint_puts_NN
        # items, but it will require a lot of precision; another approach is to utilize something like
        # Diffy to see what converted to what.
        if original_lines.count != new_lines.count
          # TODO: Report this via log + more explanation.
          puts "Can't apply RuboCop autocorrect: #{document.file}"
          next
        end
        # FIXME: Remove this or put to log. Helpful to observe progress on large codebase
        # TODO: Maybe some progress output like Rubocop does?..
        puts document.file

        original_lines.zip(new_lines).each_with_index.select { |(o, n), i| o != n }
          .each do |(from, to), idx|
            from.strip!
            to.strip!
            # TODO: skip oddities, like "from is empty" or just spaces difference
            ln = extracted_source.source_map.fetch(idx + 1)
            corrector.edit_line(ln) {
              # Slim is able to treat indents as Ruby block start (auto-adding ` do`), and this might
              # lead to mismatch of processed/actual code, compensate for that
              if !_1.include?(from) && from.end_with?(' do') && _1.include?(from.delete_suffix(' do'))
                from.delete_suffix!(' do')
              end
              # TODO: warning if it was still not found (can be SlimLint reporting the offense
              # in the wrong line)
              _1.sub(from, to)
            }
          end
      end
    end

    private

    # Executes RuboCop against the given Ruby code and records the offenses as
    # lints.
    #
    # @param ruby [String] Ruby code
    # @param source_map [Hash] map of Ruby code line numbers to original line
    #   numbers in the template
    def find_lints(ruby, source_map)
      rubocop = ::RuboCop::CLI.new
      # Inject slim-lint specific settings into the default config
      ::RuboCop::ConfigLoader.default_configuration =
        ::RuboCop::ConfigLoader.merge(::RuboCop::ConfigLoader.default_configuration, rubocop_config)

      filename = document.file ? "#{document.file}.rb" : 'ruby_script.rb'

      with_ruby_from_stdin(ruby) do
        extract_lints_from_offenses(lint_file(rubocop, filename), source_map)
      end.then { @rubocop_output = _1&.sub(/\A=+\n/, '') }
    end

    # Defined so we can stub the results in tests
    #
    # @param rubocop [RuboCop::CLI]
    # @param file [String]
    # @return [Array<RuboCop::Cop::Offense>]
    def lint_file(rubocop, file)
      rubocop.run(rubocop_flags << file)
      OffenseCollector.offenses
    end

    # Aggregates RuboCop offenses and converts them to {SlimLint::Lint}s
    # suitable for reporting.
    #
    # @param offenses [Array<RuboCop::Cop::Offense>]
    # @param source_map [Hash]
    def extract_lints_from_offenses(offenses, source_map)
      offenses.each do |offense|
        # TODO: Report if something is correctible
        @lints << Lint.new(self,
                           document.file,
                           source_map[offense.line],
                           offense.message)
      end
    end

    # Returns flags that will be passed to RuboCop CLI.
    #
    # @return [Array<String>]
    def rubocop_flags
      flags = %w[--format SlimLint::OffenseCollector]
      # TODO: ? Distinguish rubocop's --autocorrect (safe, few corrections) and --autocorrect-all
      flags += ['--autocorrect-all'] if @autocorrect
      flags += ['--config', ENV['SLIM_LINT_RUBOCOP_CONF']] if ENV['SLIM_LINT_RUBOCOP_CONF']
      flags += ['--only', config['only']] if config['only']
      flags += ['--stdin']
      flags
    end

    # Overrides the global stdin to allow RuboCop to read Ruby code from it.
    #
    # @param ruby [String] the Ruby code to write to the overridden stdin
    # @param _block [Block] the block to perform with the overridden stdin
    # @return [void]
    def with_ruby_from_stdin(ruby, &_block)
      # We send source to correct from fake STDIN and catch autocorrected source
      # on fake STDOUT.
      original_stdin = $stdin
      original_stdout = $stdout

      stdin = StringIO.new
      stdin.write(ruby)
      stdin.rewind
      $stdin = stdin

      stdout = StringIO.new
      $stdout = stdout
      yield
      stdout.string
    ensure
      $stdin = original_stdin
      $stdout = original_stdout
    end

    def rubocop_config
      to_disable = config.fetch('ignored_cops', [])

      # Disable those when run experimental autocorrect; they change source too much for it to be
      # ported back into Slim automatically, so when `slim-lint` is run with `--autocorrect` option,
      # they are skipped. But they are useful, so without autocorrect option they are reported
      # (unfortunately, we can't tell Rubocop "report it, but not autocorrect")
      to_disable.concat(config.fetch('non_correctible_cops', [])) if @autocorrect

      to_disable.to_h { [_1, {'Enabled' => false}] }
    end
  end

  # Collects offenses detected by RuboCop.
  class OffenseCollector < ::RuboCop::Formatter::BaseFormatter
    class << self
      # List of offenses reported by RuboCop.
      attr_accessor :offenses
    end

    # Executed when RuboCop begins linting.
    #
    # @param _target_files [Array<String>]
    def started(_target_files)
      self.class.offenses = []
    end

    # Executed when a file has been scanned by RuboCop, adding the reported
    # offenses to our collection.
    #
    # @param _file [String]
    # @param offenses [Array<RuboCop::Cop::Offense>]
    def file_finished(_file, offenses)
      self.class.offenses += offenses
    end
  end
end

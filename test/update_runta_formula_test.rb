# frozen_string_literal: true

require "minitest/autorun"
require "tmpdir"
require_relative "../scripts/update-runta-formula"

class RuntaFormulaUpdaterTest < Minitest::Test
  FORMULA = <<~RUBY.freeze
    class Runta < Formula
      version "0.1.19"

      on_macos do
        on_arm do
          url "https://github.com/runta-dev/homebrew-tap/releases/download/v\#{version}/runta-\#{version}-aarch64-apple-darwin.zip"
          sha256 "#{"a" * 64}"
        end
      end
    end
  RUBY

  def test_updates_version_url_and_sha256
    with_formula do |path|
      RuntaFormulaUpdater.new(path, "0.1.22", "b" * 64).update

      updated = File.read(path)
      assert_includes updated, 'version "0.1.22"'
      assert_includes updated, "runta-dev/runta/releases/download/v\#{version}"
      assert_includes updated, %Q(sha256 "#{"b" * 64}")
    end
  end

  def test_refuses_a_downgrade
    with_formula do |path|
      error = assert_raises(SystemExit) do
        RuntaFormulaUpdater.new(path, "0.1.18", "b" * 64).update
      end

      refute_predicate error, :success?
      assert_includes File.read(path), 'version "0.1.19"'
    end
  end

  def test_rejects_an_invalid_sha256
    with_formula do |path|
      error = assert_raises(SystemExit) do
        RuntaFormulaUpdater.new(path, "0.1.22", "invalid").update
      end

      refute_predicate error, :success?
    end
  end

  def test_requires_exactly_one_formula_url
    with_formula(FORMULA.sub(/^\s*url.*\n/, "")) do |path|
      error = assert_raises(SystemExit) do
        RuntaFormulaUpdater.new(path, "0.1.22", "b" * 64).update
      end

      refute_predicate error, :success?
    end
  end

  private

  def with_formula(contents = FORMULA)
    Dir.mktmpdir do |directory|
      path = File.join(directory, "runta.rb")
      File.write(path, contents)
      yield path
    end
  end
end

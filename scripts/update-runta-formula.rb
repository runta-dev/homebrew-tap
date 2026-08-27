# frozen_string_literal: true

require "rubygems"

# Updates the Runta Formula from a verified upstream release artifact.
class RuntaFormulaUpdater
  VERSION_PATTERN = /\A\d+\.\d+\.\d+\z/
  SHA256_PATTERN = /\A[0-9a-f]{64}\z/
  RELEASE_URL = "https://github.com/runta-dev/runta/releases/download/v\#{version}/runta-\#{version}-aarch64-apple-darwin.zip"

  def initialize(path, version, sha256)
    @path = path
    @version = version
    @sha256 = sha256
  end

  def update
    validate_inputs!

    contents = File.read(@path)
    current_version = capture_once(contents, /^\s*version "([^"]+)"$/, "version")
    capture_once(contents, /^\s*url "([^"]+)"$/, "URL")
    capture_once(contents, /^\s*sha256 "([0-9a-f]+)"$/, "SHA256")

    if Gem::Version.new(@version) <= Gem::Version.new(current_version)
      abort "error: refusing to replace #{current_version} with #{@version}"
    end

    contents.sub!(/^\s*version "[^"]+"$/, %Q(  version "#{@version}"))
    contents.sub!(/^\s*url "[^"]+"$/, %Q(      url "#{RELEASE_URL}"))
    contents.sub!(/^\s*sha256 "[0-9a-f]+"$/, %Q(      sha256 "#{@sha256}"))

    File.write(@path, contents)
  end

  private

  def validate_inputs!
    abort "error: invalid Runta version: #{@version}" unless VERSION_PATTERN.match?(@version)
    abort "error: invalid SHA256: #{@sha256}" unless SHA256_PATTERN.match?(@sha256)
  end

  def capture_once(contents, pattern, field)
    matches = contents.scan(pattern)
    abort "error: expected exactly one #{field} in #{@path}" if matches.length != 1

    matches.first.first
  end
end

if $PROGRAM_NAME == __FILE__
  abort "usage: #{$PROGRAM_NAME} FORMULA VERSION SHA256" if ARGV.length != 3

  RuntaFormulaUpdater.new(*ARGV).update
end

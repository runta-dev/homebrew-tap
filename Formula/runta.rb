class Runta < Formula
  desc "CLI for the Runta service"
  homepage "https://github.com/runta-dev/runta"
  version "0.2.9"

  on_macos do
    on_arm do
      url "https://github.com/runta-dev/homebrew-tap/releases/download/v#{version}/runta-#{version}-aarch64-apple-darwin.zip"
      sha256 "f4ef61bee0c7a2db9293c4e3f8778760079a035741d0990d082c2e73bc8de8b8"
    end

    on_intel do
      odie "runta only supports Apple Silicon"
    end
  end

  def install
    bin.install "runta"
  end

  test do
    assert_match version.to_s, shell_output("#{bin}/runta --version")
  end
end

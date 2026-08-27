class Runta < Formula
  desc "CLI for the Runta service"
  homepage "https://github.com/runta-dev/runta"
  version "0.1.21"

  on_macos do
    on_arm do
      url "https://github.com/runta-dev/homebrew-tap/releases/download/v#{version}/runta-#{version}-aarch64-apple-darwin.zip"
      sha256 "9feddf046a8fdd99bf7a3ed502745411604ea9af7e10f4677df79e2632957801"
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

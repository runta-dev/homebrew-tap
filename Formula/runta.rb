class Runta < Formula
  desc "CLI for the Runta service"
  homepage "https://github.com/runta-dev/runta"
  version "0.2.16"

  on_macos do
    on_arm do
      url "https://github.com/runta-dev/homebrew-tap/releases/download/v#{version}/runta-#{version}-aarch64-apple-darwin.zip"
      sha256 "d2e8f0d55ac9e3e2005397023413389e36456e5d9ce787c27ad2e2f7a6c1159b"
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

class Runta < Formula
  desc "CLI for the Runta service"
  homepage "https://github.com/runta-dev/runta"
  version "0.0.5"

  on_macos do
    on_arm do
      url "https://github.com/runta-dev/homebrew-tap/releases/download/v#{version}/runta-#{version}-aarch64-apple-darwin.tar.gz"
      sha256 "b35751cee8692b28e6aa5a3be3c315f00bbc6bb88896ada730c9b61773a5e1a8"
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

class Runta < Formula
  desc "CLI for the Runta service"
  homepage "https://github.com/runta-dev/runta"
  version "0.0.1"

  on_macos do
    on_arm do
      url "https://github.com/runta-dev/homebrew-tap/releases/download/v#{version}/runta-#{version}-aarch64-apple-darwin.tar.gz"
      sha256 "086ac3524233628b2a33305476c9094e6d8697e0874f4256aedcb58803818db9"
    end
    on_intel do
      odie "runta only supports Apple Silicon"
    end
  end

  def install
    bin.install "runta"
    system "codesign", "--force", "--sign", "-", bin/"runta"
  end

  test do
    assert_match version.to_s, shell_output("#{bin}/runta --version")
  end
end

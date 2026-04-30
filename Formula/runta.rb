class Runta < Formula
  desc "CLI for the Runta service"
  homepage "https://github.com/runta-dev/runta"
  version "0.0.2"

  on_macos do
    on_arm do
      url "https://github.com/runta-dev/homebrew-tap/releases/download/v#{version}/runta-#{version}-aarch64-apple-darwin.tar.gz"
      sha256 "0fbf38ce3130ab779cfe9450a35e8effc74a099d8dcb7e48ac16c088a24641fd"
    end
    on_intel do
      odie "runta only supports Apple Silicon"
    end
  end

  def install
    bin.install "runta"
    quiet_system "xattr", "-d", "com.apple.quarantine", bin/"runta"
    system "codesign", "--force", "--sign", "-", bin/"runta"
  end

  test do
    assert_match version.to_s, shell_output("#{bin}/runta --version")
  end
end

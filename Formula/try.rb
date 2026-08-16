class Try < Formula
  desc "Fresh directories for every experiment - native Swift rewrite of tobi/try"
  homepage "https://github.com/sraisl/try-swift"
  url "https://github.com/sraisl/try-swift/archive/refs/tags/v0.1.0.tar.gz"
  sha256 "f765ff7f74065b6b3b45411b39016fa9258291fb1e5e05ae4e3ecc4c628798dc"
  license "MIT"

  head "https://github.com/sraisl/try-swift.git", branch: "main"

  depends_on xcode: ["15.0", :build]
  depends_on "git"

  def install
    system "swift", "build", "-c", "release", "--disable-sandbox"
    bin.install ".build/release/try"
  end

  def caveats
    <<~EOS
      To set up try with your shell, add one of the following to your shell configuration:

        For bash/zsh (~/.bashrc or ~/.zshrc):
          eval "$(try init ~/src/tries)"

        For fish (~/.config/fish/config.fish):
          eval (try init ~/src/tries | string collect)

      You can change ~/src/tries to any directory where you want your experiments stored,
      or just run `try install` to do this automatically.
    EOS
  end

  test do
    assert_match "ephemeral workspace manager", shell_output("#{bin}/try --help 2>&1", 0)
  end
end

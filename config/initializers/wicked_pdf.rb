# wkhtmltopdf binary resolution order:
#   1. WKHTMLTOPDF_BINARY env variable (set this on the server if the binary lives elsewhere)
#   2. Natively installed binaries (/usr/local/bin, /usr/bin) — e.g. `sudo apt-get install -y wkhtmltopdf`
#   3. The wkhtmltopdf-binary gem's already-extracted native binary
#   4. The wkhtmltopdf-binary gem's Ruby wrapper script (last resort: it spawns a new Ruby
#      process which breaks when the server's PATH Ruby differs from the app's Ruby/Bundler env)
module WkhtmltopdfBinary
  SYSTEM_PATHS = %w[/usr/local/bin/wkhtmltopdf /usr/bin/wkhtmltopdf].freeze

  def self.resolve
    candidates.find { |path| executable?(path) }
  end

  def self.candidates
    [ ENV["WKHTMLTOPDF_BINARY"].presence, *SYSTEM_PATHS, *gem_native_binaries, gem_wrapper ].compact.uniq
  end

  def self.executable?(path)
    path.present? && File.file?(path) && File.executable?(path)
  end

  def self.gem_wrapper
    Gem.bin_path("wkhtmltopdf-binary", "wkhtmltopdf")
  rescue Gem::Exception
    nil
  end

  def self.gem_native_binaries
    wrapper = gem_wrapper
    return [] if wrapper.blank?

    Dir[File.join(File.dirname(wrapper), "wkhtmltopdf_*")].reject { |path| path.end_with?(".gz", ".rb") }
  end
end

WickedPdf.configure do |config|
  config.exe_path = WkhtmltopdfBinary.resolve || "/usr/bin/wkhtmltopdf"
end

ActiveSupport.on_load(:action_view) do
  include WickedPdf::WickedPdfHelper::Assets
end

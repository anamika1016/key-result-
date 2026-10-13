module PdfRendering
  extend ActiveSupport::Concern

  included do
    helper_method :pdf_image_data_uri
  end

  private

  # Renders a wicked_pdf template. If wkhtmltopdf is missing or crashes on the server,
  # the same template is shown as a printable HTML page instead of a 500 error.
  def render_pdf_with_fallback(filename:, template:, layout: "pdf", **options)
    ensure_wkhtmltopdf_binary!
    render pdf: filename, template: template, formats: [ :pdf ], layout: layout, **options
  rescue StandardError => e
    raise if e.is_a?(ActionView::Template::Error)

    Rails.logger.error("[PDF] #{filename} generation failed: #{e.class}: #{e.message}")
    response.headers.delete("Content-Disposition")
    content = render_to_string(template: template, formats: [ :pdf ], layout: false)
    render html: pdf_fallback_document(filename, content), content_type: "text/html"
  end

  def pdf_fallback_document(title, content)
    <<~HTML.html_safe
      <!DOCTYPE html>
      <html>
        <head>
          <meta charset="utf-8">
          <meta name="viewport" content="width=device-width, initial-scale=1">
          <title>#{ERB::Util.html_escape(title)}</title>
          <style>
            body { margin: 0; padding: 12px; background: #fff; -webkit-print-color-adjust: exact; print-color-adjust: exact; }
            .pdf-fallback-toolbar { text-align: right; margin-bottom: 12px; font-family: Arial, sans-serif; }
            .pdf-fallback-toolbar button { padding: 8px 16px; border: 0; border-radius: 6px; background: #2563eb; color: #fff; font-weight: bold; cursor: pointer; }
            @media print { body { padding: 0; } .pdf-fallback-toolbar { display: none !important; } }
          </style>
        </head>
        <body>
          <div class="pdf-fallback-toolbar"><button type="button" onclick="window.print()">Print / Save as PDF</button></div>
          #{content}
        </body>
      </html>
    HTML
  end

  def ensure_wkhtmltopdf_binary!
    return if WkhtmltopdfBinary.executable?(WickedPdf.config[:exe_path].to_s)

    resolved = WkhtmltopdfBinary.resolve
    WickedPdf.config[:exe_path] = resolved if resolved.present?
  end

  # Base64 data URI for an image in app/assets/images that never raises in production.
  def pdf_image_data_uri(filename)
    path = Rails.root.join("app/assets/images", filename)
    return "" unless File.file?(path)

    mime = Marcel::MimeType.for(Pathname.new(path), name: filename)
    "data:#{mime};base64,#{Base64.strict_encode64(File.binread(path))}"
  rescue StandardError
    ""
  end
end

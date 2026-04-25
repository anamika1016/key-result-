module QuizzesHelper
  def quiz_qr_svg_data(qr_text, size: 250)
    require "rqrcode"
    require "rqrcode/export/svg"

    qr = RQRCode::QRCode.new(qr_text)
    svg = qr.as_svg(
      offset: 0,
      color: "000",
      shape_rendering: "crispEdges",
      module_size: 2,
      standalone: true,
      use_path: true,
      viewbox: true,
      width: size,
      height: size
    )

    svg.sub("<svg ", %(<svg width="#{size}" height="#{size}" style="width: #{size}px; height: #{size}px; display: block;" )).html_safe
  rescue LoadError
    content_tag(
      :div,
      "QR gem not installed yet. Please run bundle install and restart Rails.",
      class: "rounded-xl border border-amber-200 bg-amber-50 px-4 py-3 text-center text-sm font-medium text-amber-700"
    )
  end
end

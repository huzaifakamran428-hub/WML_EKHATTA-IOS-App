import UIKit
import PDFKit

/// SRS 4.6 (Bill Layout), 15 (Professional Bill Specification), extended
/// per owner request into a bigger, bolder, more modern receipt:
///
///   TOP     -> logo mark, store name, store address, store phone
///   MIDDLE  -> receipt/bill info + pricing
///   BOTTOM  -> laptop details (centered), then customer/shopkeeper
///              name + address + phone
///
/// Shared by both the customer sale bill (`buildSaleBillPDF`) and the new
/// shopkeeper combined bill (`buildShopkeeperBillPDF`, one bill covering
/// every laptop the shopkeeper has taken, not one bill per laptop).
enum PDFBuilder {

    // MARK: - Shared modern styling

    private static let pageWidth: CGFloat = 612   // US Letter
    private static let pageHeight: CGFloat = 792
    private static let margin: CGFloat = 40

    private static let brandDark = UIColor(red: 0.10, green: 0.15, blue: 0.30, alpha: 1)
    private static let brandAccent = UIColor(red: 0.90, green: 0.58, blue: 0.09, alpha: 1)
    private static let boxFill = UIColor(red: 0.96, green: 0.96, blue: 0.98, alpha: 1)
    private static let boxBorder = UIColor(red: 0.82, green: 0.83, blue: 0.87, alpha: 1)

    private struct Cursor { var y: CGFloat }

    private static func draw(_ text: String, at point: CGPoint, font: UIFont, color: UIColor = .black, alignment: NSTextAlignment = .left, width: CGFloat? = nil) -> CGFloat {
        let paragraph = NSMutableParagraphStyle()
        paragraph.alignment = alignment
        let attrs: [NSAttributedString.Key: Any] = [.font: font, .foregroundColor: color, .paragraphStyle: paragraph]
        let boxWidth = width ?? (pageWidth - margin * 2)
        let rect = CGRect(x: point.x, y: point.y, width: boxWidth, height: 200)
        (text as NSString).draw(with: rect, options: .usesLineFragmentOrigin, attributes: attrs, context: nil)
        let size = (text as NSString).boundingRect(with: CGSize(width: boxWidth, height: .greatestFiniteMagnitude), options: .usesLineFragmentOrigin, attributes: attrs, context: nil)
        return size.height
    }

    private static func drawRoundedRect(_ rect: CGRect, fill: UIColor?, stroke: UIColor?, radius: CGFloat = 10) {
        let path = UIBezierPath(roundedRect: rect, cornerRadius: radius)
        if let fill = fill { fill.setFill(); path.fill() }
        if let stroke = stroke { stroke.setStroke(); path.lineWidth = 1; path.stroke() }
    }

    /// Bold, modern header band: logo mark on the left, store name/address/
    /// phone stacked to its right, all on a dark band that anchors the top
    /// of every bill (SRS: "on the upside there should be logo, our
    /// address, phone number").
    private static func drawHeader(store: StoreSettings, logoImage: UIImage?) -> CGFloat {
        let bandHeight: CGFloat = 118
        drawRoundedRect(CGRect(x: 0, y: 0, width: pageWidth, height: bandHeight), fill: brandDark, stroke: nil, radius: 0)

        let logoSize: CGFloat = 64
        let logoRect = CGRect(x: margin, y: (bandHeight - logoSize) / 2, width: logoSize, height: logoSize)
        if let logoImage = logoImage ?? UIImage(named: "Logo") {
            // IMPORTANT: addClip() applies to the current graphics context
            // for the rest of this page unless explicitly restored. Without
            // save/restore here, every draw() call after the logo (store
            // address, totals, laptop details, billed-to, footer) would be
            // silently clipped to this small circle and never appear.
            let ctx = UIGraphicsGetCurrentContext()
            ctx?.saveGState()
            let path = UIBezierPath(roundedRect: logoRect, cornerRadius: logoSize / 2)
            path.addClip()
            logoImage.draw(in: logoRect)
            ctx?.restoreGState()
        } else {
            drawRoundedRect(logoRect, fill: brandAccent, stroke: nil, radius: logoSize / 2)
            let initials = store.storeName
                .split(separator: " ")
                .prefix(2)
                .compactMap { $0.first.map(String.init) }
                .joined()
            _ = draw(initials, at: CGPoint(x: logoRect.minX, y: logoRect.minY + 16), font: .boldSystemFont(ofSize: 22), color: .white, alignment: .center, width: logoSize)
        }

        let textX = logoRect.maxX + 18
        let textWidth = pageWidth - textX - margin
        var ty = bandHeight / 2 - 34
        ty += draw(store.storeName, at: CGPoint(x: textX, y: ty), font: .boldSystemFont(ofSize: 24), color: .white, width: textWidth) + 4
        ty += draw(store.address, at: CGPoint(x: textX, y: ty), font: .systemFont(ofSize: 12), color: UIColor.white.withAlphaComponent(0.85), width: textWidth) + 2
        if !store.phoneNumber.isEmpty {
            ty += draw("Phone: \(store.phoneNumber)", at: CGPoint(x: textX, y: ty), font: .systemFont(ofSize: 12, weight: .semibold), color: UIColor.white.withAlphaComponent(0.85), width: textWidth) + 2
        }
        // Owner request: every bill also shows the CEO's name + contact
        // number, right under the store phone in the header band.
        if !store.ceoName.isEmpty || !store.ceoContactNumber.isEmpty {
            let parts = [
                store.ceoName.isEmpty ? nil : "CEO: \(store.ceoName)",
                store.ceoContactNumber.isEmpty ? nil : "Contact No: \(store.ceoContactNumber)",
            ].compactMap { $0 }
            _ = draw(parts.joined(separator: "   ·   "), at: CGPoint(x: textX, y: ty), font: .systemFont(ofSize: 12, weight: .semibold), color: UIColor.white.withAlphaComponent(0.85), width: textWidth)
        }
        return bandHeight + 26
    }

    /// Bold receipt/bill-info line: reference number + date, right under
    /// the header, so it reads like a real modern invoice.
    private static func drawBillInfo(referenceLabel: String, referenceNo: String, dateText: String, y: CGFloat) -> CGFloat {
        var cursor = y
        _ = draw(referenceLabel, at: CGPoint(x: margin, y: cursor), font: .systemFont(ofSize: 12, weight: .semibold), color: .secondaryLabel)
        _ = draw("Date", at: CGPoint(x: pageWidth - margin - 200, y: cursor), font: .systemFont(ofSize: 12, weight: .semibold), color: .secondaryLabel, alignment: .right, width: 200)
        cursor += 16
        _ = draw(referenceNo, at: CGPoint(x: margin, y: cursor), font: .boldSystemFont(ofSize: 22), color: brandDark)
        _ = draw(dateText, at: CGPoint(x: pageWidth - margin - 200, y: cursor), font: .boldSystemFont(ofSize: 15), color: .black, alignment: .right, width: 200)
        cursor += 34
        let line = UIBezierPath()
        line.move(to: CGPoint(x: margin, y: cursor))
        line.addLine(to: CGPoint(x: pageWidth - margin, y: cursor))
        boxBorder.setStroke(); line.lineWidth = 1; line.stroke()
        return cursor + 20
    }

    /// One bold pricing/summary row, e.g. "Total Amount ...... Rs. 90,000".
    private static func drawSummaryRow(_ label: String, _ value: String, y: CGFloat, emphasize: Bool = false) -> CGFloat {
        let font: UIFont = emphasize ? .boldSystemFont(ofSize: 17) : .systemFont(ofSize: 14, weight: .medium)
        let color: UIColor = emphasize ? brandDark : .darkGray
        _ = draw(label, at: CGPoint(x: margin, y: y), font: font, color: color, width: 260)
        _ = draw(value, at: CGPoint(x: pageWidth - margin - 260, y: y), font: font, color: color, alignment: .right, width: 260)
        return y + font.lineHeight + 10
    }

    /// SRS: "on the bottom center there should be the details of that
    /// laptop" -- boxed, centered heading, big bold spec lines.
    private static func drawLaptopDetailsBox(title: String, lines: [String], y: CGFloat) -> CGFloat {
        let boxWidth = pageWidth - margin * 2
        let lineHeight: CGFloat = 20
        let boxHeight: CGFloat = 34 + CGFloat(lines.count) * lineHeight
        let rect = CGRect(x: margin, y: y, width: boxWidth, height: boxHeight)
        drawRoundedRect(rect, fill: boxFill, stroke: boxBorder, radius: 12)

        _ = draw(title, at: CGPoint(x: margin, y: y + 10), font: .boldSystemFont(ofSize: 15), color: brandDark, alignment: .center, width: boxWidth)
        var ly = y + 34
        for line in lines {
            _ = draw(line, at: CGPoint(x: margin, y: ly), font: .systemFont(ofSize: 13, weight: .medium), color: .darkGray, alignment: .center, width: boxWidth)
            ly += lineHeight
        }
        return y + boxHeight + 22
    }

    /// SRS: "downside customer name, its address, its phone number" --
    /// bold, large, clearly labelled "Billed To" block.
    private static func drawBilledTo(name: String, phone: String?, address: String?, y: CGFloat) -> CGFloat {
        var cursor = y
        _ = draw("BILLED TO", at: CGPoint(x: margin, y: cursor), font: .systemFont(ofSize: 11, weight: .bold), color: brandAccent)
        cursor += 16
        _ = draw(name, at: CGPoint(x: margin, y: cursor), font: .boldSystemFont(ofSize: 18), color: .black)
        cursor += 24
        if let phone = phone, !phone.isEmpty {
            _ = draw("Phone: \(phone)", at: CGPoint(x: margin, y: cursor), font: .systemFont(ofSize: 13), color: .darkGray)
            cursor += 18
        }
        if let address = address, !address.isEmpty {
            _ = draw("Address: \(address)", at: CGPoint(x: margin, y: cursor), font: .systemFont(ofSize: 13), color: .darkGray)
            cursor += 18
        }
        return cursor + 10
    }

    private static func drawFooter(store: StoreSettings) {
        var fy = pageHeight - 70
        _ = draw(store.address, at: CGPoint(x: margin, y: fy), font: .systemFont(ofSize: 10), color: .gray, alignment: .center)
        fy += 14
        if !store.thankYouMessage.isEmpty {
            _ = draw(store.thankYouMessage, at: CGPoint(x: margin, y: fy), font: .italicSystemFont(ofSize: 12), color: brandDark, alignment: .center)
        }
    }

    // MARK: - Customer sale bill (one laptop, from Inventory)

    static func buildBillPDF(sale: Sale, laptop: Laptop?, customerName: String, customerPhone: String? = nil, customerAddress: String? = nil, store: StoreSettings, logoImage: UIImage? = nil) -> Data {
        let renderer = UIGraphicsPDFRenderer(bounds: CGRect(x: 0, y: 0, width: pageWidth, height: pageHeight))
        return renderer.pdfData { context in
            context.beginPage()
            var y = drawHeader(store: store, logoImage: logoImage)
            y = drawBillInfo(referenceLabel: "RECEIPT NO.", referenceNo: sale.receiptNo, dateText: AppDateFormat.displayString(fromAPIDate: sale.saleDate), y: y)

            y = drawSummaryRow("Original Price", CurrencyFormatter.format(sale.salePrice), y: y)
            if sale.discountAmount > 0 || sale.discountPercent > 0 {
                y = drawSummaryRow("Discount", "- \(CurrencyFormatter.format(sale.discountAmount))", y: y)
            }
            y = drawSummaryRow("Final Price", CurrencyFormatter.format(sale.finalTotal), y: y, emphasize: true)
            y = drawSummaryRow("Amount Received", CurrencyFormatter.format(sale.amountReceived), y: y)
            y = drawSummaryRow("Remaining", CurrencyFormatter.format(sale.remainingAmount), y: y, emphasize: sale.remainingAmount > 0)
            y += 14

            if let laptop = laptop {
                // Owner request: bill only shows brand, model, generation,
                // CPU, RAM and storage — condition, serial number and CPU
                // core count are dropped from the printed bill (still
                // visible on the Laptop Details screen in the app itself).
                let lines = [
                    "\(laptop.brand) \(laptop.modelName)\(laptop.generation.map { " — \($0)" } ?? "")",
                    "\(laptop.processor), \(laptop.ram), \(laptop.storage)",
                ]
                y = drawLaptopDetailsBox(title: "LAPTOP DETAILS", lines: lines, y: y)
            }

            _ = drawBilledTo(name: customerName, phone: customerPhone, address: customerAddress, y: y)
            drawFooter(store: store)
        }
    }

    // MARK: - Shopkeeper combined bill (one bill, every laptop they've taken)

    /// SRS-style owner requirement: a shopkeeper's bill always covers every
    /// laptop AND every extra-money entry under their one account, not one
    /// bill per laptop -- always one combined total. Each row shows its
    /// own remaining figure, and "(Cleared)" once that row itself is fully
    /// paid off, even though the shopkeeper's payments are made one at a
    /// time against specific targets.
    static func buildShopkeeperBillPDF(shopkeeper: Shopkeeper, store: StoreSettings, logoImage: UIImage? = nil) -> Data {
        let renderer = UIGraphicsPDFRenderer(bounds: CGRect(x: 0, y: 0, width: pageWidth, height: pageHeight))
        return renderer.pdfData { context in
            context.beginPage()
            var y = drawHeader(store: store, logoImage: logoImage)
            y = drawBillInfo(referenceLabel: "SHOPKEEPER ACCOUNT NO.", referenceNo: shopkeeper.referenceNumber, dateText: AppDateFormat.display.string(from: Date()), y: y)

            y = drawSummaryRow("Total Amount (laptops + extra money)", CurrencyFormatter.format(shopkeeper.totalAmount), y: y)
            y = drawSummaryRow("Total Received", CurrencyFormatter.format(shopkeeper.totalReceived), y: y)
            y = drawSummaryRow("Remaining Balance", CurrencyFormatter.format(shopkeeper.remainingAmount), y: y, emphasize: shopkeeper.remainingAmount > 0)
            y += 10

            let laptopLines = shopkeeper.laptops.map { item -> String in
                let spec = [item.coreGeneration, item.ram, item.storage].compactMap { $0 }.filter { !$0.isEmpty }.joined(separator: ", ")
                let specText = spec.isEmpty ? "" : " (\(spec))"
                let status = item.isCleared ? "Cleared" : "\(CurrencyFormatter.format(item.remainingAmount)) remaining"
                return "\(item.itemReference): \(item.brand) \(item.modelName)\(specText) — \(CurrencyFormatter.format(item.price)), \(status)"
            }
            let extraMoneyLines = shopkeeper.extraMoney.map { entry -> String in
                let status = entry.isCleared ? "Cleared" : "\(CurrencyFormatter.format(entry.remainingAmount)) remaining"
                let note = (entry.note?.isEmpty == false) ? " (\(entry.note!))" : ""
                return "\(entry.itemReference): 💵 Extra Money\(note) — \(CurrencyFormatter.format(entry.amount)), \(status)"
            }
            let allLines = laptopLines + extraMoneyLines
            let title = "LAPTOP & EXTRA MONEY DETAILS (\(shopkeeper.laptops.count) laptop\(shopkeeper.laptops.count == 1 ? "" : "s")"
                + (extraMoneyLines.isEmpty ? "" : ", \(shopkeeper.extraMoney.count) extra money entr\(shopkeeper.extraMoney.count == 1 ? "y" : "ies")") + ")"
            y = drawLaptopDetailsBox(title: title, lines: allLines.isEmpty ? ["No laptops or extra money added yet."] : allLines, y: y)

            _ = drawBilledTo(name: shopkeeper.name, phone: shopkeeper.phone, address: shopkeeper.address, y: y)
            drawFooter(store: store)
        }
    }
}

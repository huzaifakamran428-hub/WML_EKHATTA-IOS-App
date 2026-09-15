import UIKit
import PDFKit

/// Screen 7 — SRS 4.6 (Bill Layout), 15 (Professional Bill Specification):
/// professional PDF preview, creation and iOS share sheet. Also used for
/// the new shopkeeper combined bill (one bill, every laptop they've
/// taken) via the `shopkeeper` initializer.
final class BillPreviewViewController: UIViewController {
    private let sale: Sale?
    private let laptop: Laptop?
    private let customerName: String?
    private let customerPhone: String?
    private let customerAddress: String?
    private let shopkeeper: Shopkeeper?

    private let pdfView = PDFView()
    private var pdfData: Data?
    private var fileNameHint: String { sale?.receiptNo ?? shopkeeper?.referenceNumber ?? "Bill" }

    /// Customer sale bill (one laptop, sold from Inventory).
    init(sale: Sale, laptop: Laptop?, customerName: String, customerPhone: String? = nil, customerAddress: String? = nil) {
        self.sale = sale
        self.laptop = laptop
        self.customerName = customerName
        self.customerPhone = customerPhone
        self.customerAddress = customerAddress
        self.shopkeeper = nil
        super.init(nibName: nil, bundle: nil)
    }

    /// Shopkeeper combined bill (every laptop under their one account).
    init(shopkeeper: Shopkeeper) {
        self.sale = nil
        self.laptop = nil
        self.customerName = nil
        self.customerPhone = nil
        self.customerAddress = nil
        self.shopkeeper = shopkeeper
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) { fatalError() }

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .systemBackground
        title = "Bill Preview"
        navigationItem.rightBarButtonItem = UIBarButtonItem(barButtonSystemItem: .action, target: self, action: #selector(share))
        // A completed sale hides the back button (SRS 8.2); a shopkeeper
        // bill is just a preview reached from their account, so back stays.
        navigationItem.hidesBackButton = sale != nil

        pdfView.translatesAutoresizingMaskIntoConstraints = false
        pdfView.autoScales = true
        view.addSubview(pdfView)
        NSLayoutConstraint.activate([
            pdfView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            pdfView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            pdfView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            pdfView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
        ])

        Task { await generateBill() }

        if sale != nil {
            let doneButton = UIButton(type: .system)
            doneButton.setTitle("Done", for: .normal)
            doneButton.addTarget(self, action: #selector(finish), for: .touchUpInside)
            navigationItem.leftBarButtonItem = UIBarButtonItem(customView: doneButton)
        }
    }

    private func generateBill() async {
        do {
            let settings = try await StoreSettingsService.shared.get()
            let logo = await Self.fetchLogo(urlString: settings.logoURL)
            let data: Data
            if let sale = sale {
                data = PDFBuilder.buildBillPDF(
                    sale: sale, laptop: laptop, customerName: customerName ?? "Customer",
                    customerPhone: customerPhone, customerAddress: customerAddress,
                    store: settings, logoImage: logo
                )
            } else if let shopkeeper = shopkeeper {
                data = PDFBuilder.buildShopkeeperBillPDF(shopkeeper: shopkeeper, store: settings, logoImage: logo)
            } else {
                return
            }
            await MainActor.run {
                self.pdfData = data
                self.pdfView.document = PDFDocument(data: data)
            }
        } catch {
            // SRS 17: 'Bill generation failure shows: Bill could not be
            // generated. Please try again.'
            await MainActor.run { self.presentErrorAlert(APIError.server("Bill could not be generated. Please try again.")) }
        }
    }

    /// Best-effort fetch of the store logo for the bill header; the bill
    /// still renders a clean monogram badge if this fails or isn't set.
    private static func fetchLogo(urlString: String?) async -> UIImage? {
        guard let urlString = urlString, let url = URL(string: urlString) else { return nil }
        guard let (data, _) = try? await URLSession.shared.data(from: url) else { return nil }
        return UIImage(data: data)
    }

    @objc private func share() {
        guard let data = pdfData else { return }
        let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent("Receipt-\(fileNameHint).pdf")
        try? data.write(to: tempURL)
        let activity = UIActivityViewController(activityItems: [tempURL], applicationActivities: nil)
        present(activity, animated: true)
    }

    @objc private func finish() {
        navigationController?.popToRootViewController(animated: true)
    }
}

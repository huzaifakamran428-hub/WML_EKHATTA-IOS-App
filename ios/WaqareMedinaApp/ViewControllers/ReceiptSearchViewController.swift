import UIKit

/// Screen 22 — SRS 6.3: search by receipt/reference number and related
/// sale ('searching 00025 directly finds Receipt No. 00025').
final class ReceiptSearchViewController: UIViewController {
    private let field = FormTextField(label: "Receipt / Reference Number", keyboardType: .numberPad)
    private let searchButton = UIButton(type: .system)
    private let resultLabel = UILabel()
    private let errorLabel = UILabel()

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .systemBackground
        title = "Receipt Search"

        searchButton.setTitle("Search", for: .normal)
        searchButton.titleLabel?.font = .boldSystemFont(ofSize: 17)
        searchButton.backgroundColor = .systemBlue
        searchButton.setTitleColor(.white, for: .normal)
        searchButton.layer.cornerRadius = 10
        searchButton.heightAnchor.constraint(equalToConstant: 48).isActive = true
        searchButton.addTarget(self, action: #selector(search), for: .touchUpInside)

        errorLabel.textColor = .systemRed
        errorLabel.numberOfLines = 0
        errorLabel.isHidden = true
        resultLabel.numberOfLines = 0

        let stack = UIStackView(arrangedSubviews: [field, searchButton, errorLabel, resultLabel])
        stack.axis = .vertical
        stack.spacing = 16
        stack.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(stack)
        NSLayoutConstraint.activate([
            stack.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 20),
            stack.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 16),
            stack.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -16),
        ])
    }

    @objc private func search() {
        errorLabel.isHidden = true
        // Receipt numbers are zero-padded to 5 digits (SRS 12); accept raw
        // digits and pad automatically so '25' finds '00025'.
        let raw = field.text?.trimmingCharacters(in: .whitespaces) ?? ""
        guard let number = Int(raw), (1...99_999).contains(number) else {
            errorLabel.text = "Please enter a valid receipt number."
            errorLabel.isHidden = false
            return
        }
        let receiptNo = String(format: "%05d", number)
        Task {
            do {
                let sale = try await SalesService.shared.findByReceipt(receiptNo)
                await MainActor.run {
                    let vc = CustomerSaleDetailsViewController(sale: sale, customerName: "Customer #\(sale.customer)")
                    self.navigationController?.pushViewController(vc, animated: true)
                }
            } catch {
                await MainActor.run {
                    self.errorLabel.text = error.localizedDescription
                    self.errorLabel.isHidden = false
                }
            }
        }
    }
}

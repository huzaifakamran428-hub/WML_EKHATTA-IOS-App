import UIKit
import PhotosUI

/// Screen 5 — SRS 4.3, 8.1 (Laptop Purchase / Inventory Workflow): Add/edit
/// laptop form, optional photo (never required to save).
final class AddEditLaptopViewController: UIViewController {
    private let laptop: Laptop?
    private let scroll = UIScrollView()
    private let stack = UIStackView()

    private let brandField = FormTextField(label: "Brand *")
    private let modelField = FormTextField(label: "Model *")
    private let generationField = FormTextField(label: "Generation")
    private let processorField = FormTextField(label: "Processor / CPU *")
    private let coresField = FormTextField(label: "CPU Cores *", keyboardType: .numberPad)
    private let ramField = FormTextField(label: "RAM *")
    private let storageField = FormTextField(label: "Storage *")
    private let gpuField = FormTextField(label: "GPU")
    private let screenField = FormTextField(label: "Screen Size")
    private let serialField = FormTextField(label: "Serial Number")
    private let purchasePriceField = FormTextField(label: "Purchase Price *", keyboardType: .decimalPad)
    private let salePriceField = FormTextField(label: "Sale Price *", keyboardType: .decimalPad)
    private let discountField = FormTextField(label: "Discount (amount)", keyboardType: .decimalPad)
    private let quantityField = FormTextField(label: "Quantity *", keyboardType: .numberPad)
    private let supplierField = FormTextField(label: "Supplier")
    private let warrantyField = FormTextField(label: "Warranty")
    private let notesField = FormTextField(label: "Notes")
    // Condition picker removed per owner request (Sep 2026): it wasn't
    // being used, and leaving a UISegmentedControl with no default
    // selection meant selectedSegmentIndex could be -1 (UISegmentedControl
    // .noSegment) if the admin never tapped it -- indexing
    // LaptopCondition.allCases[-1] then crashed the app on Save. Every
    // laptop is now saved as "New" (LaptopCondition.new) without asking.
    private let photoButton = UIButton(type: .system)
    private let saveButton = UIButton(type: .system)
    private let errorLabel = UILabel()

    init(laptop: Laptop?) {
        self.laptop = laptop
        super.init(nibName: nil, bundle: nil)
    }
    required init?(coder: NSCoder) { fatalError() }

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .systemBackground
        title = laptop == nil ? "Add Laptop" : "Edit Laptop"
        enableTapToDismissKeyboard()

        photoButton.setTitle("Add Photo (optional)", for: .normal)
        photoButton.addTarget(self, action: #selector(pickPhoto), for: .touchUpInside)

        errorLabel.textColor = .systemRed
        errorLabel.numberOfLines = 0
        errorLabel.font = .systemFont(ofSize: 13)
        errorLabel.isHidden = true

        saveButton.setTitle("Save Laptop", for: .normal)
        saveButton.titleLabel?.font = .boldSystemFont(ofSize: 17)
        saveButton.backgroundColor = .systemBlue
        saveButton.setTitleColor(.white, for: .normal)
        saveButton.layer.cornerRadius = 10
        saveButton.heightAnchor.constraint(equalToConstant: 48).isActive = true
        saveButton.addTarget(self, action: #selector(save), for: .touchUpInside)

        // Save is pinned as a fixed footer (outside the scroll view) rather
        // than as the last item in the scrollable stack, so it's always
        // reachable without having to scroll through every field first.
        let footer = UIView()
        footer.backgroundColor = .systemBackground
        footer.translatesAutoresizingMaskIntoConstraints = false
        footer.addSubview(saveButton)
        saveButton.translatesAutoresizingMaskIntoConstraints = false

        let fields = [
            brandField, modelField, generationField, processorField, coresField, ramField,
            storageField, gpuField, screenField, serialField, purchasePriceField, salePriceField, discountField,
            quantityField, supplierField, warrantyField, notesField, photoButton, errorLabel,
        ]
        stack.axis = .vertical
        stack.spacing = 14
        stack.translatesAutoresizingMaskIntoConstraints = false
        fields.forEach { stack.addArrangedSubview($0) }

        scroll.translatesAutoresizingMaskIntoConstraints = false
        scroll.keyboardDismissMode = .interactive
        view.addSubview(scroll)
        view.addSubview(footer)
        scroll.addSubview(stack)
        NSLayoutConstraint.activate([
            scroll.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            scroll.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            scroll.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            scroll.bottomAnchor.constraint(equalTo: footer.topAnchor),
            stack.topAnchor.constraint(equalTo: scroll.topAnchor, constant: 16),
            stack.leadingAnchor.constraint(equalTo: scroll.leadingAnchor, constant: 16),
            stack.trailingAnchor.constraint(equalTo: scroll.trailingAnchor, constant: -16),
            stack.bottomAnchor.constraint(equalTo: scroll.bottomAnchor, constant: -16),
            stack.widthAnchor.constraint(equalTo: scroll.widthAnchor, constant: -32),

            footer.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            footer.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            footer.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor),
            saveButton.topAnchor.constraint(equalTo: footer.topAnchor, constant: 12),
            saveButton.bottomAnchor.constraint(equalTo: footer.bottomAnchor, constant: -12),
            saveButton.leadingAnchor.constraint(equalTo: footer.leadingAnchor, constant: 16),
            saveButton.trailingAnchor.constraint(equalTo: footer.trailingAnchor, constant: -16),
        ])
        registerKeyboardAvoidance(for: scroll)

        if let laptop = laptop { populate(laptop) }
    }

    private func populate(_ laptop: Laptop) {
        brandField.text = laptop.brand
        modelField.text = laptop.modelName
        generationField.text = laptop.generation
        processorField.text = laptop.processor
        coresField.text = "\(laptop.cpuCores)"
        ramField.text = laptop.ram
        storageField.text = laptop.storage
        gpuField.text = laptop.gpu
        screenField.text = laptop.screenSize
        serialField.text = laptop.serialNumber
        purchasePriceField.text = "\(laptop.purchasePrice)"
        salePriceField.text = "\(laptop.salePrice)"
        discountField.text = "\(laptop.discountAmount)"
        quantityField.text = "\(laptop.quantity)"
        supplierField.text = laptop.supplier
        warrantyField.text = laptop.warranty
        notesField.text = laptop.notes
    }

    @objc private func pickPhoto() {
        // SRS 3.1: PhotosUI / UIImagePickerController. Photo upload wiring
        // (multipart request) attaches here; omitted from this scaffold
        // since it never blocks saving (SRS 4.3).
        var config = PHPickerConfiguration()
        config.filter = .images
        let picker = PHPickerViewController(configuration: config)
        present(picker, animated: true)
    }

    @objc private func save() {
        errorLabel.isHidden = true
        do {
            let brand = try Validator.requireNonEmpty(brandField.text, fieldName: "brand")
            let model = try Validator.requireNonEmpty(modelField.text, fieldName: "model")
            let processor = try Validator.requireNonEmpty(processorField.text, fieldName: "processor")
            let cores = Int(coresField.text ?? "") ?? 0
            let ram = try Validator.requireNonEmpty(ramField.text, fieldName: "RAM")
            let storage = try Validator.requireNonEmpty(storageField.text, fieldName: "storage")
            let purchasePrice = try Validator.requirePositiveDecimal(purchasePriceField.text, fieldName: "purchase price")
            let salePrice = try Validator.requirePositiveDecimal(salePriceField.text, fieldName: "sale price")
            let discount = Decimal(string: discountField.text ?? "") ?? 0
            let quantity = Int(quantityField.text ?? "") ?? 0
            // Condition selection removed (see property comment above) --
            // always save as "New" without asking, so this can never
            // crash on an unset segmented control again.
            let condition = LaptopCondition.new

            let form = LaptopFormData(
                brand: brand, model_name: model, generation: generationField.text, processor: processor,
                cpu_cores: cores, ram: ram, storage: storage, gpu: gpuField.text, screen_size: screenField.text,
                condition: condition, serial_number: serialField.text, purchase_price: purchasePrice,
                sale_price: salePrice, discount_amount: discount, discount_percent: 0, quantity: quantity,
                supplier: supplierField.text, warranty: warrantyField.text, notes: notesField.text
            )

            saveButton.isEnabled = false
            Task {
                do {
                    if let laptop = laptop {
                        _ = try await InventoryService.shared.update(id: laptop.id, form)
                    } else {
                        _ = try await InventoryService.shared.create(form)
                    }
                    await MainActor.run { self.showSuccessThenPop(laptop == nil ? "Laptop added successfully." : "Laptop updated successfully.") }
                } catch {
                    await MainActor.run { self.showError(error) }
                }
                await MainActor.run { self.saveButton.isEnabled = true }
            }
        } catch {
            showError(error)
        }
    }

    private func showSuccessThenPop(_ message: String) {
        let alert = UIAlertController(title: "Success", message: message, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "OK", style: .default) { [weak self] _ in
            self?.navigationController?.popViewController(animated: true)
        })
        present(alert, animated: true)
    }

    private func showError(_ error: Error) {
        // Also updates the inline label (visible once scrolled to it), but
        // the alert is what guarantees the user actually sees the error —
        // errorLabel alone can be scrolled out of view in this long form.
        errorLabel.text = error.localizedDescription
        errorLabel.isHidden = false
        presentErrorAlert(error)
    }
}

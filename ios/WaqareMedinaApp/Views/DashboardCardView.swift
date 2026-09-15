import UIKit

/// SRS 4.2: Dashboard summary cards with navigation to detail screens.
final class DashboardCardView: UIView {
    private let titleLabel = UILabel()
    private let valueLabel = UILabel()
    var onTap: (() -> Void)?

    init(title: String, value: String) {
        super.init(frame: .zero)
        translatesAutoresizingMaskIntoConstraints = false
        backgroundColor = .secondarySystemBackground
        layer.cornerRadius = 12

        titleLabel.text = title
        titleLabel.font = .systemFont(ofSize: 13, weight: .medium)
        titleLabel.textColor = .secondaryLabel

        valueLabel.text = value
        valueLabel.font = .systemFont(ofSize: 22, weight: .bold)
        valueLabel.textColor = .label
        valueLabel.numberOfLines = 1
        valueLabel.adjustsFontSizeToFitWidth = true

        let stack = UIStackView(arrangedSubviews: [titleLabel, valueLabel])
        stack.axis = .vertical
        stack.spacing = 4
        stack.translatesAutoresizingMaskIntoConstraints = false
        addSubview(stack)
        NSLayoutConstraint.activate([
            stack.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 14),
            stack.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -14),
            stack.topAnchor.constraint(equalTo: topAnchor, constant: 12),
            stack.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -12),
        ])

        let tap = UITapGestureRecognizer(target: self, action: #selector(handleTap))
        addGestureRecognizer(tap)
        isUserInteractionEnabled = true
    }
    required init?(coder: NSCoder) { fatalError() }

    @objc private func handleTap() { onTap?() }

    func update(value: String) { valueLabel.text = value }
}

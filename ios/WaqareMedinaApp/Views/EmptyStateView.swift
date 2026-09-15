import UIKit

/// SRS 17: clear, friendly feedback states reused across list screens.
final class EmptyStateView: UIView {
    private let label = UILabel()

    init(message: String) {
        super.init(frame: .zero)
        translatesAutoresizingMaskIntoConstraints = false
        label.text = message
        label.textColor = .secondaryLabel
        label.font = .systemFont(ofSize: 15)
        label.textAlignment = .center
        label.numberOfLines = 0
        label.translatesAutoresizingMaskIntoConstraints = false
        addSubview(label)
        NSLayoutConstraint.activate([
            label.centerXAnchor.constraint(equalTo: centerXAnchor),
            label.centerYAnchor.constraint(equalTo: centerYAnchor),
            label.leadingAnchor.constraint(greaterThanOrEqualTo: leadingAnchor, constant: 24),
            label.trailingAnchor.constraint(lessThanOrEqualTo: trailingAnchor, constant: -24),
        ])
    }
    required init?(coder: NSCoder) { fatalError() }
}

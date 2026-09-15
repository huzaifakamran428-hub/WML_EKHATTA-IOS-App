import Foundation

/// SRS 4.3 (Laptop Product / Inventory Record), 7 (Product/Laptop entity)
enum LaptopCondition: String, Codable, CaseIterable {
    case new = "NEW"
    case used = "USED"
    case refurbished = "REFURBISHED"

    var displayText: String {
        switch self {
        case .new: return "New"
        case .used: return "Used"
        case .refurbished: return "Refurbished"
        }
    }
}

struct Laptop: Codable, Equatable {
    let id: Int
    var brand: String
    var modelName: String
    var generation: String?
    var processor: String
    var cpuCores: Int
    var ram: String
    var storage: String
    var gpu: String?
    var screenSize: String?
    var condition: LaptopCondition
    var serialNumber: String?
    var purchasePrice: Decimal
    var salePrice: Decimal
    var discountAmount: Decimal
    var discountPercent: Decimal
    var quantity: Int
    var supplier: String?
    var purchaseDate: String?
    var warranty: String?
    var photoURL: String?
    var notes: String?
    var isArchived: Bool
    var finalPrice: Decimal
    var isLowStock: Bool
    var isOutOfStock: Bool

    enum CodingKeys: String, CodingKey {
        case id, brand, processor, ram, storage, gpu, condition
        case modelName = "model_name"
        case generation
        case cpuCores = "cpu_cores"
        case screenSize = "screen_size"
        case serialNumber = "serial_number"
        case purchasePrice = "purchase_price"
        case salePrice = "sale_price"
        case discountAmount = "discount_amount"
        case discountPercent = "discount_percent"
        case quantity, supplier
        case purchaseDate = "purchase_date"
        case warranty
        case photoURL = "photo"
        case notes
        case isArchived = "is_archived"
        case finalPrice = "final_price"
        case isLowStock = "is_low_stock"
        case isOutOfStock = "is_out_of_stock"
    }

    /// Mirrors apps/core/business_rules.calculate_final_price on the Swift
    /// side for instant UI feedback (SRS 3.3: 'Business-critical
    /// calculations must be validated by Django even when the Swift app
    /// performs immediate UI calculations.')
    static func previewFinalPrice(salePrice: Decimal, discountAmount: Decimal, discountPercent: Decimal) -> Decimal {
        var price = salePrice
        if discountPercent > 0 {
            price -= (price * discountPercent / 100)
        }
        if discountAmount > 0 {
            price -= discountAmount
        }
        return max(price, 0)
    }
}

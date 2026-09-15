import Foundation

/// SRS 4.7 (Separate Customer and Shopkeeper sections), 7 (Customer /
/// Shopkeeper entities)
struct Customer: Codable, Equatable {
    let id: Int
    var name: String
    var phone: String
    var address: String?
    var notes: String?
}

/// SRS 4.7 (Shopkeeper), extended: a Shopkeeper is created ONCE and reused
/// for every laptop/extra-money they take afterward. Everything lives
/// under this one record, with one combined bill (`referenceNumber`),
/// instead of a new shopkeeper/receipt each time.
enum ShopkeeperStatus: String, Codable {
    case active = "ACTIVE"
    case cleared = "CLEARED"

    var displayText: String {
        self == .cleared ? "ALL INSTALLMENTS CLEARED — PAID IN FULL" : "Active"
    }
}

struct Shopkeeper: Codable, Equatable {
    let id: Int
    let referenceNumber: String
    var name: String
    var phone: String
    var cnic: String?
    var address: String?
    var notes: String?
    var laptops: [ShopkeeperLaptopItem]
    var extraMoney: [ShopkeeperExtraMoney]
    var payments: [ShopkeeperPayment]
    let totalAmount: Decimal
    let totalReceived: Decimal
    let remainingAmount: Decimal
    let status: ShopkeeperStatus

    enum CodingKeys: String, CodingKey {
        case id, name, phone, cnic, address, notes, laptops, payments, status
        case referenceNumber = "reference_number"
        case extraMoney = "extra_money"
        case totalAmount = "total_amount"
        case totalReceived = "total_received"
        case remainingAmount = "remaining_amount"
    }

    /// SRS-style rule carried over from CreditPlan: the "Add Payment"
    /// action disappears once the combined balance is fully cleared.
    var canAddPayment: Bool { status == .active && remainingAmount > 0 }
}

/// A single laptop taken by a shopkeeper on installment -- picked from
/// shop Inventory. Brand/model/specs are copied from Inventory when added
/// and are fixed afterward (not editable); only `price` (the rate given
/// to this shopkeeper, separate from the shop's own sale price) can change.
struct ShopkeeperLaptopItem: Codable, Equatable, Identifiable {
    let id: Int
    let itemReference: String
    var shopkeeper: Int
    let brand: String
    let modelName: String
    let coreGeneration: String?
    let ram: String?
    let storage: String?
    let condition: String?
    let notes: String?
    var price: Decimal
    let addedAt: String
    let paidAmount: Decimal
    let remainingAmount: Decimal
    let isCleared: Bool

    enum CodingKeys: String, CodingKey {
        case id, shopkeeper, brand, price, notes, ram, storage, condition
        case itemReference = "item_reference"
        case modelName = "model_name"
        case coreGeneration = "core_generation"
        case addedAt = "added_at"
        case paidAmount = "paid_amount"
        case remainingAmount = "remaining_amount"
        case isCleared = "is_cleared"
    }

    /// One line for display: "Dell Latitude 5490 · 8th Gen · 8 GB · 256 GB SSD"
    var specSummary: String {
        [brand, modelName].joined(separator: " ")
    }
    var specDetail: String {
        [coreGeneration, ram, storage, condition].compactMap { $0 }.filter { !$0.isEmpty }.joined(separator: " · ")
    }
}

/// Request body for POST /api/shopkeeper-laptops/ ("Add another laptop")
/// -- picked from Inventory. Only the Inventory item's id and the price
/// given to this shopkeeper are sent; every spec field is copied
/// server-side and comes back read-only.
struct NewShopkeeperLaptopRequest: Codable {
    let shopkeeper: Int
    let inventoryLaptop: Int
    let price: Decimal

    enum CodingKeys: String, CodingKey {
        case shopkeeper, price
        case inventoryLaptop = "inventory_laptop"
    }
}

/// Request body for PATCH /api/shopkeeper-laptops/{id}/ -- only the price
/// can be edited once a laptop has been added; specs are fixed.
struct UpdateShopkeeperLaptopRequest: Codable {
    let price: Decimal
}

/// Extra cash a shopkeeper takes on top of laptops -- its own separate
/// receipt line, rolled into the shopkeeper's one combined bill total.
struct ShopkeeperExtraMoney: Codable, Equatable, Identifiable {
    let id: Int
    let itemReference: String
    var shopkeeper: Int
    var amount: Decimal
    var note: String?
    let addedAt: String
    let paidAmount: Decimal
    let remainingAmount: Decimal
    let isCleared: Bool

    enum CodingKeys: String, CodingKey {
        case id, shopkeeper, amount, note
        case itemReference = "item_reference"
        case addedAt = "added_at"
        case paidAmount = "paid_amount"
        case remainingAmount = "remaining_amount"
        case isCleared = "is_cleared"
    }
}

struct NewShopkeeperExtraMoneyRequest: Codable {
    let shopkeeper: Int
    let amount: Decimal
    let note: String?
}

struct UpdateShopkeeperExtraMoneyRequest: Codable {
    let amount: Decimal
    let note: String?
}

/// What a shopkeeper payment clears -- the "Extra Money / Laptop Payment"
/// dropdown. Not sent to the server directly; used by the Add Payment
/// screen to build the right request.
enum ShopkeeperPaymentTarget: Equatable {
    case laptop(ShopkeeperLaptopItem)
    case extraMoney(ShopkeeperExtraMoney)

    var remainingAmount: Decimal {
        switch self {
        case .laptop(let item): return item.remainingAmount
        case .extraMoney(let entry): return entry.remainingAmount
        }
    }

    var label: String {
        switch self {
        case .laptop(let item): return "\(item.itemReference) — \(item.specSummary)"
        case .extraMoney(let entry): return "\(entry.itemReference) — 💵 Extra Money"
        }
    }
}

/// One payment against a shopkeeper's account, always targeted at exactly
/// one laptop or one extra-money entry (the dropdown) -- POST
/// /api/shopkeeper-payments/. `note` always travels with the payment and
/// is shown alongside it everywhere.
struct ShopkeeperPayment: Codable, Equatable, Identifiable {
    let id: Int
    let shopkeeper: Int
    let laptopItem: Int?
    let extraMoney: Int?
    let amount: Decimal
    let paymentDate: String
    let method: PaymentMethod
    var note: String?

    enum CodingKeys: String, CodingKey {
        case id, shopkeeper, amount, method, note
        case laptopItem = "laptop_item"
        case extraMoney = "extra_money"
        case paymentDate = "payment_date"
    }
}

struct NewShopkeeperPaymentRequest: Codable {
    let shopkeeper: Int
    let laptopItem: Int?
    let extraMoney: Int?
    let amount: Decimal
    let method: PaymentMethod
    let note: String?

    enum CodingKeys: String, CodingKey {
        case shopkeeper, amount, method, note
        case laptopItem = "laptop_item"
        case extraMoney = "extra_money"
    }
}

/// Request body for PATCH /api/shopkeeper-payments/{id}/ -- editing an
/// already-recorded payment's amount/method/note. The target (which
/// laptop/extra money it clears) is not changed here -- delete and re-add
/// if it was recorded against the wrong thing.
struct UpdateShopkeeperPaymentRequest: Codable {
    let amount: Decimal
    let method: PaymentMethod
    let note: String?
}

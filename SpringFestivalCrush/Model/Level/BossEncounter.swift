import Foundation

struct BossEncounter {
    let configuration: BossConfiguration
    private(set) var health: Int
    private(set) var turns = 0
    private(set) var attackLane = 0
    private(set) var lastDamage = 0
    private var creditedArmor = Set<ObjectIdentifier>()

    init(configuration: BossConfiguration) {
        self.configuration = configuration
        health = configuration.health
    }

    var movesUntilAttack: Int { configuration.attackInterval - turns % configuration.attackInterval }
    var tribute: SymbolType { (turns / configuration.attackInterval).isMultiple(of: 2) ? .redPocket : .dumpling }
    var nextAttackLane: Int { (turns / configuration.attackInterval * 2 + 2) % 9 }
    var cue: String {
        guard health > 0 else { return String(localized: "Guardian defeated!") }
        switch configuration.kind {
        case .rat:
            return tribute == .redPocket
                ? String(localized: "Match red envelopes · raid in \(movesUntilAttack) moves")
                : String(localized: "Match dumplings · raid in \(movesUntilAttack) moves")
        case .ox: return String(localized: "Break armor / trigger specials · charge in \(movesUntilAttack) moves")
        case .tiger: return String(localized: "Firecrackers + cascades · row \(9 - nextAttackLane) freezes in \(movesUntilAttack) moves")
        }
    }

    mutating func receive(chains: Set<Chain>, cascadeDepth: Int) {
        guard health > 0 else { return }
        let cleared = Set(chains.flatMap(\.clearedSymbols))
        let armor = Set(chains.flatMap { $0.resistedSymbols }).subtracting(creditedArmor)
        creditedArmor.formUnion(armor)
        let damage: Int
        switch configuration.kind {
        case .rat:
            damage = cleared.filter { $0.collectionType.isMatchableTo(tribute) }.count
        case .ox:
            let enhanced = cleared.filter { $0.type.isEnhanced }.count
            let specials = Set(chains.filter { $0.chainType == .fiveEffect || $0.chainType == .lightning }
                .map { $0.chainType.description }).count
            let combined = chains.reduce(0) { $0 + ($1.combination?.fiveCount ?? 0) + ($1.combination?.lightningCount ?? 0) }
            let reactions = chains.flatMap(\.detonations).filter { $0.type == .five || $0.type == .lightning }.count
            let convertedBolts = chains.flatMap(\.transformedSymbols).filter { $0.type == .lightning }.count
            damage = armor.count * 2 + (enhanced + specials + combined + reactions + convertedBolts) * 4
        case .tiger:
            damage = cleared.filter { $0.collectionType.isMatchableTo(.firecracker) || (cascadeDepth >= 2 && $0.collectionType.isNormalMatchable) }.count
        }
        lastDamage = min(health, damage)
        health = max(0, health - damage)
    }

    /// Called only after a paid, valid move has fully settled. Never on a tool or invalid swap.
    mutating func advanceTurn() -> Bool {
        guard health > 0 else { return false }
        attackLane = nextAttackLane
        turns += 1
        creditedArmor.removeAll()
        return turns.isMultiple(of: configuration.attackInterval)
    }
}

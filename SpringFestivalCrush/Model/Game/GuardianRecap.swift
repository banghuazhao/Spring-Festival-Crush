/// Read-only guardian health for pause and continue feedback.
struct GuardianRecap: Equatable {
    let health: Int
    let maximumHealth: Int

    init?(health: Int, maximumHealth: Int) {
        guard maximumHealth > 0 else { return nil }
        self.health = max(0, min(health, maximumHealth))
        self.maximumHealth = maximumHealth
    }

    var isDefeated: Bool { health == 0 }

    /// Only a surviving guardian with at most one quarter of its health is nearly beaten.
    var isAlmostBeaten: Bool {
        health > 0 && health < maximumHealth && health <= maximumHealth / 4
    }
}

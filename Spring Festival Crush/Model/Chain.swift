class Chain: Hashable, CustomStringConvertible {
    var cookies: [Cookie] = []
    var score = 0

    enum ChainType: CustomStringConvertible {
        case horizontal
        case vertical

        var description: String {
            switch self {
            case .horizontal: return "Horizontal"
            case .vertical: return "Vertical"
            }
        }
    }

    var chainType: ChainType
    init(chainType: ChainType) {
        self.chainType = chainType
    }

    func add(cookie: Cookie) {
        cookies.append(cookie)
    }

    func firstCookie() -> Cookie {
        return cookies[0]
    }

    func lastCookie() -> Cookie {
        return cookies[cookies.count - 1]
    }

    var length: Int {
        return cookies.count
    }

    var description: String {
        return "type:\(chainType) cookies:\(cookies)"
    }

    var hashValue: Int {
        return cookies.reduce(0) { $0.hashValue ^ $1.hashValue }
    }

    static func == (lhs: Chain, rhs: Chain) -> Bool {
        return lhs.cookies == rhs.cookies
    }
}

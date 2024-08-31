struct Array2D<T> {
    let columns: Int
    let rows: Int
    private var array: [T?]

    init(columns: Int, rows: Int) {
        self.columns = columns
        self.rows = rows
        array = Array<T?>(repeating: nil, count: rows * columns)
    }

    subscript(column: Int, row: Int) -> T? {
        get {
            return array[row * columns + column]
        }
        set {
            array[row * columns + column] = newValue
        }
    }
    
    func nonNilElements() -> [T] {
        array.compactMap { $0 }
    }

    func normalMatchableElements() -> Int where T == Symbol {
        var count = 0
        for element in array {
            if let element, element.type.isNormalMatchable {
                count += 1
            }
        }
        return count
    }

    func surroundingsElementsFor(column: Int, row: Int) -> [T] {
        var elements = [T]()
        let surroundingPositions = [
            [column + 1, row],
            [column - 1, row],
            [column + 1, row + 1],
            [column - 1, row + 1],
            [column + 1, row - 1],
            [column - 1, row - 1],
            [column, row + 1],
            [column, row - 1],
        ]
        for surroundingPosition in surroundingPositions {
            let surroundingColumn = surroundingPosition[0]
            let surroundingRow = surroundingPosition[1]

            if surroundingRow >= 0 && surroundingRow < rows,
               surroundingColumn >= 0 && surroundingColumn < columns,
               let element = array[surroundingRow * columns + surroundingColumn] {
                elements.append(element)
            }
        }
        return elements
    }

    func adjacentElementsFor(column: Int, row: Int) -> [T] {
        var elements = [T]()
        let adjacentPositions = [
            [column + 1, row],
            [column - 1, row],
            [column, row + 1],
            [column, row - 1],
        ]
        for adjacentPosition in adjacentPositions {
            let adjacentColumn = adjacentPosition[0]
            let adjacentRow = adjacentPosition[1]

            if adjacentRow >= 0 && adjacentRow < rows,
               adjacentColumn >= 0 && adjacentColumn < columns,
               let element = array[adjacentRow * columns + adjacentColumn] {
                elements.append(element)
            }
        }
        return elements
    }
}

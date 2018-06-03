class Node {
    var visited = false
    var connections: [Connection] = []
}

class Connection {
    public let to: Node
    public let weight: Double
    
    public init(to node: Node, weight: Double) {
        assert(weight >= 0, "weight has to be equal or greater than zero")
        self.to = node
        self.weight = weight
    }
}

class Path: Comparable {
    public let cumulativeWeight: Double
    public let node: Node
    public let previousPath: Path?
    
    init(to node: Node, via connection: Connection? = nil, previousPath path: Path? = nil) {
        if
            let previousPath = path,
            let viaConnection = connection {
            self.cumulativeWeight = viaConnection.weight + previousPath.cumulativeWeight
        } else {
            self.cumulativeWeight = 0
        }
        
        self.node = node
        self.previousPath = path
    }
    
    static func < (lhs: Path, rhs: Path) -> Bool {
        return lhs.cumulativeWeight < rhs.cumulativeWeight
    }
    
    static func == (lhs: Path, rhs: Path) -> Bool {
        return lhs.cumulativeWeight == rhs.cumulativeWeight
    }
}

extension Path {
    var array: [Node] {
        var array: [Node] = [self.node]
        
        var iterativePath = self
        while let path = iterativePath.previousPath {
            array.append(path.node)
            
            iterativePath = path
        }
        
        return array
    }
}

class PathFinder {
    static func test(){
        class MyNode: Node {
            let name: String
            
            init(name: String) {
                self.name = name
                super.init()
            }
        }
        
        let nodeA = MyNode(name: "A")
        let nodeB = MyNode(name: "B")
        let nodeC = MyNode(name: "C")
        let nodeD = MyNode(name: "D")
        let nodeE = MyNode(name: "E")
        
        nodeA.connections.append(Connection(to: nodeB, weight: 1))
        nodeB.connections.append(Connection(to: nodeC, weight: 3))
        nodeC.connections.append(Connection(to: nodeD, weight: 1))
        nodeB.connections.append(Connection(to: nodeE, weight: 1))
        nodeE.connections.append(Connection(to: nodeC, weight: 1))
        
        let sourceNode = nodeA
        let destinationNode = nodeD
        
        let path = shortestPath(source: sourceNode, destination: destinationNode)
        
        if let succession: [String] = path?.array.reversed().flatMap({ $0 as? MyNode}).map({$0.name}) {
            print("🏁 Quickest path: \(succession)")
        } else {
            print("💥 No path between \(sourceNode.name) & \(destinationNode.name)")
        }
    }
    
    static func purgeVisited(nodes: [Node]){
        for node in nodes {
            node.visited = false
        }
    }
    
    static func shortestPath(source: Node, destination: Node) -> Path? {
        var pathPQ: PriorityQueue<Path> =
            PriorityQueue(ascending: true, startingValues: [Path(to: source)])
        
        while !pathPQ.isEmpty {
            let cheapest = pathPQ.pop()!
            guard !cheapest.node.visited else { continue }
            
            if cheapest.node === destination { return cheapest }
            
            cheapest.node.visited = true
            
            for connection in cheapest.node.connections
                where !connection.to.visited {
                pathPQ.push(Path(to: connection.to, via: connection, previousPath: cheapest))
            }
        }
        return nil
    }
}

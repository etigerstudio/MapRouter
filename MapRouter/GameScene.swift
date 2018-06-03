//
//  GameScene.swift
//  MapRouter
//
//  Created by ALuier Bondar on 17/12/2017.
//  Copyright © 2017 E-Tiger Studio. All rights reserved.
//

import SpriteKit
import GameplayKit

class GameScene: SKScene,NSGestureRecognizerDelegate {
    
    private var nodesLabel : SKLabelNode?
    private var distanceLabel : SKLabelNode?
    private var progressLabel : SKLabelNode?
    private var nodesBoard : SKNode?
    private var distanceBoard : SKNode?
    private var dotNode = SKNode()
    private var connectionNode = SKShapeNode()
    
    private var lastPos : CGPoint = CGPoint.zero
    private var lastScale : CGFloat = 0
    
    //private var nodesLoaded = false
    //private var nodesRendered = false
    //private var nodes = [(index:Int,x:Int,y:Int)]()
    //private var edges = [(n1:Int,n2:Int)]()
    private var nodes = [DotNode]()
    private var pathNode = SKShapeNode()
    private var selectedNodes = [DotSpriteNode]()
    
    private var borderNodes = [SKSpriteNode]()
    private var borderNodeFirst = true
    
    private let maxScale:CGFloat = 20.0
    private let initialScale:CGFloat = 16.0
    private let xInitialPos:Int = -10000
    private let yInitialPos:Int = -4200
    
    private var connectionRendered = false
    
    private let NORMAL_TEXTURE = "Node/Default"
    private let SELECTED_TEXTURE = "Node/Selected"
    private let HIGHLIGHT_ACTION_KEY = "highlight-action"
    private let CONCEAL_ACTION_KEY = "conceal-action"
    private let BORDER_ACTION_KEY = "border-action"
    private let HIGHLIGHT_ACTION_NAME = "Highlight"
    private let CONCEAL_ACTION_NAME = "Conceal"
    private let BORDER_ACTION_NAME = "Border"
    private let BORDER_TEXTURE = "Node/Border"
    private let LOAD_FILE_TEXT = "正在加载节点👷"
    private let BUILD_NODES_TEXT = "正在生成节点👷"
    private let RENDER_NODES_TEXT = "正在渲染节点👷"
    private let COMPLETE_TEXT = "完成😘"
    
    override func didMove(to view: SKView) {
        loadAsync()
        
        let cameraNode = SKCameraNode()
        cameraNode.position = CGPoint(x: 0, y: 0)
        cameraNode.setScale(initialScale)
        addChild(cameraNode)
        camera = cameraNode
        
        if let nodesRect = childNode(withName: "//NodesRect"){
            nodesRect.alpha = 0
            nodesRect.removeFromParent()
            cameraNode.addChild(nodesRect)
            nodesBoard = nodesRect
        }
        if let distanceRect = childNode(withName: "//DistanceRect"){
            distanceRect.alpha = 0
            distanceRect.removeFromParent()
            cameraNode.addChild(distanceRect)
            distanceBoard = distanceRect
        }
        nodesLabel = childNode(withName: "//NodesRect/NodesLabel") as? SKLabelNode
        distanceLabel = childNode(withName: "//DistanceRect/DistanceLabel") as? SKLabelNode
        if let progressLabel = childNode(withName: "//ProgressLabel") as? SKLabelNode{
            progressLabel.removeFromParent()
            cameraNode.addChild(progressLabel)
            self.progressLabel = progressLabel
        }
        showProgress(LOAD_FILE_TEXT)
        
        let panRecognizer = NSPanGestureRecognizer(target: self, action: #selector(moveCamera(pan:)))
        panRecognizer.delegate = self
        view.addGestureRecognizer(panRecognizer)
        
        let magnifyRecognizer = NSMagnificationGestureRecognizer(target: self, action: #selector(updateCameraScale(mag:)))
        magnifyRecognizer.delegate = self
        view.addGestureRecognizer(magnifyRecognizer)
        
        pathNode.strokeColor = SKColor.green.withAlphaComponent(0.6)
        pathNode.lineWidth = 20
        pathNode.zPosition = 0.5
        addChild(pathNode)
        
        for i in 0...1 {
            borderNodes.append(SKSpriteNode(imageNamed: BORDER_TEXTURE))
            borderNodes[i].zPosition = 1.5
            borderNodes[i].isHidden = true
            addChild(borderNodes[i])
        }
    }
    
    func fetchData(){
        if let path = Bundle.main.path(forResource: "usa", ofType: "txt"){
            do {
                NSLog("1")
                let contents = try String.init(contentsOfFile: path)
                let components = contents.components(separatedBy: .whitespacesAndNewlines)
                let numbers = components.filter{!$0.isEmpty}
                showProgress(BUILD_NODES_TEXT)
                NSLog("2")
                if let nodeCount = Int(numbers[0]), let edgeCount = Int(numbers[1]){
                    var pos = 2
                    let nextInt:()->Int = {
                        pos += 1
                        return Int(numbers[pos-1])!
                    }
                    nodes.reserveCapacity(nodeCount)
                    for _ in 0..<nodeCount {
                        nodes.append(DotNode(index: nextInt(), x: nextInt(), y: nextInt()))
                    }
                    for _ in 0..<edgeCount {
                        let node1 = nodes[nextInt()]
                        let node2 = nodes[nextInt()]
                        let weight = distanceBetween(node1, and: node2)
                        let connection1 = Connection(to: node2, weight: weight)
                        let connection2 = Connection(to: node1, weight: weight)
                        node1.connections.append(connection1)
                        node2.connections.append(connection2)
                    }
                    
                    NSLog("3")
                }
            } catch {
                print(error)
            }
        }
    }
    
    func showProgress(_ text: String){
        progressLabel?.text = text
    }
    
    func hideProgress(){
        //showProgress(COMPLETE_TEXT)
        //let action  = SKAction.fadeOut(withDuration: 0.35)
        //action.timingMode = .easeIn
        //progressLabel?.run(action)
        progressLabel?.isHidden = true
    }
    
    func loadAsync(){
        let background = DispatchQueue.global()
        background.async {
            self.fetchData()
            NSLog("4")
            self.showProgress(self.RENDER_NODES_TEXT)
            self.renderGraph(count: self.nodes.count)
            self.hideProgress()
            self.showBoards()
            NSLog("5")
        }
    }
    
    func updateNodesBoard(index1: Int, index2: Int) {
        var text = "节点: ( "
        if index1 > -1 {
            text += "\(index1)"
        } else {
            text += "无"
        }
        if index2 > -1 {
            text += ", \(index2)"
        } else {
            text += ", 无"
        }
        text += " )"
        nodesLabel?.text = text
    }
    
    func updateDistanceBoard(_ distance: Double) {
        var text = "最短距离: "
        if distance>0 {
            text += String(format:"%.0lf",distance)
        } else {
            text += "--"
        }
        distanceLabel?.text = text
    }
    
    func showBoards(){
        for board in [nodesBoard, distanceBoard] {
            board?.run(SKAction(named: "Raise")!)
        }
    }
    
    func distanceBetween(_ n1: DotNode, and n2: DotNode) -> Double {
        let x = Double(n1.x-n2.x)
        let y = Double(n1.y-n2.y)
        return sqrt(x*x+y*y)
    }
   
    func renderConnection(count:Int) {
        //let cacher = SKEffectNode()
        let path = CGMutablePath()
        for i in 0..<count{
            for edge in nodes[i].connections {
                if let to = edge.to as? DotNode {
                    path.move(to: dotNode.children[nodes[i].index].position)
                    path.addLine(to: dotNode.children[to.index].position)
                }
            }
        }
        connectionNode.lineWidth = 2
        connectionNode.path = path
        connectionNode.isAntialiased = false
        addChild(connectionNode)
//        cacher.addChild(connectionNode)
//        cacher.shouldRasterize = true
//        addChild(cacher)
        //cacher.calculateAccumulatedFrame()
        //print(cacher.calculateAccumulatedFrame())
    }
    
    func renderGraph(count:Int) {
        for i in 0..<count{
            let node = DotSpriteNode(imageNamed: NORMAL_TEXTURE)
            node.id = i
            node.position = getNodePostion(i)
            dotNode.addChild(node)
            //addChild(node)
        }
        addChild(dotNode)
    }
    
    func getNodePostion(_ i:Int) -> CGPoint{
        return CGPoint(x: nodes[i].x * 2 + xInitialPos,
                       y: nodes[i].y * 2 + yInitialPos)
    }
    
    func calcShortestPath(between n1:DotNode, and n2:DotNode) -> [DotNode]{
        var result = [DotNode]()
        if let path = PathFinder.shortestPath(source: n1, destination: n2){
            for node in path.array {
                result.append(node as! DotNode)
            }
        }
        PathFinder.purgeVisited(nodes: nodes)
        return result
    }
    
    func calcDistanceBetween(nodes: [DotNode]) -> Double {
        var distance = 0.0
        for i in 0..<nodes.count-1 {
            distance += distanceBetween(nodes[i], and: nodes[i+1])
        }
        return distance
    }
    
    func renderPath(nodes: [DotNode]) {
        let path = CGMutablePath()
        path.move(to: getNodePostion(nodes[0].index))
        for i in 1..<nodes.count {
            path.addLine(to: getNodePostion(nodes[i].index))
        }
        pathNode.path = path
    }
    
    func touchDown(atPoint pos : CGPoint) {
        for node in nodes(at: pos) {
            if let dot = node as? DotSpriteNode {
                let count = selectedNodes.count
                if count == 0 {
                    setDotSelected(dot, selected: true)
                    updateNodesBoard(index1: selectedNodes[0].id, index2: -1)
                } else if count == 1 {
                    setDotSelected(dot, selected: true)
                    updateNodesBoard(index1: selectedNodes[0].id, index2: selectedNodes[1].id)
                    renderShortestPath(between: getNodeBySpriteNode(selectedNodes[0]),
                                       and: getNodeBySpriteNode(selectedNodes[1]))
                } else {
                    pathNode.path = nil
                    setDotSelected(selectedNodes[0], selected: false)
                    setDotSelected(dot, selected: true)
                    updateNodesBoard(index1: selectedNodes[0].id, index2: selectedNodes[1].id)
                    renderShortestPath(between: getNodeBySpriteNode(selectedNodes[0]),
                                       and: getNodeBySpriteNode(selectedNodes[1]))
                }
                return
            }
        }
    }
    
    func renderShortestPath(between node1: DotNode, and node2: DotNode){
        let background = DispatchQueue.global()
        background.async {
            let path = self.calcShortestPath(between: node1, and: node2)
            self.renderPath(nodes: path)
            self.dimNodes()
            for node in path {
                self.dotNode.children[node.index].alpha = 1
            }
            self.updateDistanceBoard(self.calcDistanceBetween(nodes: path))
        }
    }
    
    func dimNodes() {
        for node in self.dotNode.children {
            node.alpha = 0.4
        }
    }
    
    func lightenNodes() {
        for node in self.dotNode.children {
            node.alpha = 1
        }
    }
    
    func getNodeBySpriteNode(_ sprite: DotSpriteNode) -> DotNode {
        return nodes[sprite.id]
    }
    
    func setDotSelected(_ node: DotSpriteNode, selected: Bool){
        if selected {
            selectedNodes.append(node)
            node.zPosition = 1
            node.texture = SKTexture(imageNamed: SELECTED_TEXTURE)
            node.run(SKAction(named: HIGHLIGHT_ACTION_NAME)!, withKey: HIGHLIGHT_ACTION_KEY)
            
            let border = borderNodeFirst ? borderNodes[0] : borderNodes[1]
            border.isHidden = false
            border.setScale(5.0)
            border.position = node.position
            border.run(SKAction(named: BORDER_ACTION_NAME)!, withKey: BORDER_ACTION_KEY)
            borderNodeFirst = !borderNodeFirst
        } else {
            node.removeAction(forKey: HIGHLIGHT_ACTION_KEY)
            selectedNodes.remove(at: selectedNodes.index(of: node)!)
            node.run(SKAction(named: CONCEAL_ACTION_NAME)!){
                node.texture = SKTexture(imageNamed: self.NORMAL_TEXTURE)
                node.zPosition = 0
            }
            
            let border = borderNodeFirst ? borderNodes[0] : borderNodes[1]
            border.removeAction(forKey: BORDER_ACTION_KEY)
            border.isHidden = true
        }
    }
    
    override func mouseDown(with event: NSEvent) {
        self.touchDown(atPoint: event.location(in: self))
    }

    override func keyDown(with event: NSEvent) {
        switch event.keyCode {
        case 49:
            for node in selectedNodes {
                setDotSelected(node, selected: false)
            }
            updateDistanceBoard(0)
            updateNodesBoard(index1: -1, index2: -1)
            for border in borderNodes {
                border.isHidden = true
                border.removeAction(forKey: BORDER_ACTION_KEY)
            }
            lightenNodes()
            pathNode.path = nil
        case 8:
            if !connectionRendered {
                self.renderConnection(count: self.nodes.count)
                connectionRendered = true
            } else {
                connectionNode.isHidden = false
            }
        case 4:
            connectionNode.isHidden = true
        default: break
        }
    }
    
    @objc func moveCamera(pan: NSPanGestureRecognizer){
        let trans = pan.translation(in: view)
        switch pan.state {
        case .began:
            if let camera = camera {
                lastPos = camera.position
                setCameraTranslation(trans: trans)
            }
        default:
            setCameraTranslation(trans: trans)
        }
    }
    
    func setCameraTranslation(trans: CGPoint){
        if let camera = camera {
            camera.position.x = lastPos.x + -trans.x * camera.xScale
            camera.position.y = lastPos.y + -trans.y * camera.yScale
        }
    }
    
    @objc func updateCameraScale(mag: NSMagnificationGestureRecognizer){
        let scale = mag.magnification
        switch mag.state {
        case .began:
            if let camera = camera{
                lastScale = camera.xScale
                setCameraScale(scale: scale)
            }
        default:
            setCameraScale(scale: scale)
        }
    }
    
    func setCameraScale(scale: CGFloat) {
        var scale = abs(1/(1+scale) * lastScale)
        if scale<1 {
            scale = 1
        } else if scale > maxScale {
            scale = maxScale
        }
        camera?.setScale(scale)
    }
}

class DotNode: Node {
    let index: Int
    let x: Int
    let y: Int
    init(index: Int, x:Int, y:Int){
        self.index = index
        self.x = x
        self.y = y
    }
}

class DotSpriteNode: SKSpriteNode {
    var id:Int = 0
}

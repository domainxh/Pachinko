//
//  GameScene.swift
//  Project36_Crashy_Plane
//
//  Created by Xiaoheng Pan on 12/8/16.
//  Copyright © 2016 Xiaoheng Pan. All rights reserved.
//

import SpriteKit
import GameplayKit

enum GameState {
    case showingLogo
    case playing
    case dead
}

class GameScene: SKScene, SKPhysicsContactDelegate{
    
    var logo: SKSpriteNode!
    var gameOver: SKSpriteNode!
    var gameState = GameState.showingLogo
    
    var player: SKSpriteNode!
    var backgroundMusic: SKAudioNode! // SKAudioNode adds several useful features to audio in SpriteKit, such as the ability to pan your audio left and right. One of the neat features of SKAudioNode is that it loops its audio by default. This makes it perfect for background music: we create the music, add it directly to the game scene as a child, and it plays our background music forever. It also has the happy side effect of starting the iOS Simulator's sound system as soon as the game begins, which means you won't have your game freeze the first time the player touches a red scoring rectangle.
    var explosionMusic: SKAudioNode!
    var gameScore: SKLabelNode!
    var score: Int = 0 {
        didSet {
            gameScore.text = "Score: \(score)"
        }
    }
    
    override func didMove(to view: SKView) {
        
        createLogo()
        createPlayer()
        createSky()
        createBackground()
        createGround()
        
        if let musicURL = Bundle.main.url(forResource: "music", withExtension: "m4a") {
            backgroundMusic = SKAudioNode(url: musicURL)
            addChild(backgroundMusic)
        }
        
        physicsWorld.gravity = CGVector(dx: 0.0, dy: -5.0)
        physicsWorld.contactDelegate = self
        
    }
    
    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        
        switch gameState {
        case .showingLogo:
            gameState = .playing
            
            let fadeOut = SKAction.fadeOut(withDuration: 0.5)
            let wait = SKAction.wait(forDuration: 0.5)
            let remove = SKAction.removeFromParent()
            let activePlayer = SKAction.run { [unowned self] in
                self.player.physicsBody?.isDynamic = true
                self.startRocks()
            }
            
            let sequence = SKAction.sequence([fadeOut, wait, activePlayer, remove])
            logo.run(sequence)
            
        case .playing:
            player.physicsBody?.velocity = CGVector(dx: 0, dy: 0)
            player.physicsBody?.applyImpulse(CGVector(dx: 0, dy: 20))
            // The second line means "give the player a push upwards every time the player taps the screen." The first line is there to make the physics a bit more realistic and it effectively neutralizes any existing upward velocity the player has before applying the new movement. Without that, the player could tap multiple times quickly and apply a huge upwards force to the plane, sending them miles off the top of the screen.
            createScore()
            
        case .dead:
            let scene = GameScene(fileNamed: "GameScene")!
            let transition = SKTransition.moveIn(with: .left, duration: 1)
            self.view?.presentScene(scene, transition: transition)
        }
    }
    
    override func update(_ currentTime: TimeInterval) {
        // This makes the player's movement more dramatic. It's going to take 1/1000th of the player's upward velocity (a tiny amount) and turn that into rotation. This means that when the player is moving upwards the plane tilts up a little, and when the player is falling the plane tilts down. To make the effect nicer we'll add it as a rotate(toAngle:) action over a tenth of a second. This smooths out the rotation a little, but because it's happening more slowly than the game's frame rate it effectively means the rotation animation is always happening.
        
        guard player != nil else { return }
        
        let value = player.physicsBody!.velocity.dy * 0.001
        let rotate = SKAction.rotate(toAngle: value, duration: 0.1)
        
        player.run(rotate)
    }
    
    func createPlayer() {
        let playerTexture = SKTexture(imageNamed: "player-1")
        player = SKSpriteNode(texture: playerTexture)
        player.zPosition = 10
        player.position = CGPoint(x: frame.width / 6, y: frame.height * 0.75)
        
        addChild(player)
        
        player.physicsBody = SKPhysicsBody(texture: playerTexture, size: playerTexture.size())
        player.physicsBody?.isDynamic = false
        player.physicsBody!.contactTestBitMask = player.physicsBody!.collisionBitMask
        // This line makes SpriteKit tell us whenever the player collides with anything. This is wasteful in some games, but here the player dies if they touch anything so it's the right thing to do.
        
        player.physicsBody?.collisionBitMask = 0
        
        let frame2 = SKTexture(imageNamed: "player-2")
        let frame3 = SKTexture(imageNamed: "player-3")
        let animation = SKAction.animate(with: [playerTexture, frame2, frame3, frame2], timePerFrame: 0.01)
        let runForever = SKAction.repeatForever(animation)
        
        player.run(runForever)
    }
    
    func createSky() {
        // By default, nodes have the anchor point X0.5, Y0.5, which means they calculate their position from their horizontal and vertical center. We'll be modifying that to be X0.5, Y1 so that they measure from their center top instead – it makes it easier to position because one part of the sky will take up 67% of the screen and the other part will take up 33%.
        
        let topSky = SKSpriteNode(color: UIColor(hue: 0.55, saturation: 0.14, brightness: 0.97, alpha: 1), size: CGSize(width: frame.width, height: frame.height * 0.67))
        topSky.anchorPoint = CGPoint(x: 0.5, y: 1)
        
        let bottomSky = SKSpriteNode(color: UIColor(hue: 0.55, saturation: 0.16, brightness: 0.96, alpha: 1), size: CGSize(width: frame.width, height: frame.height * 0.33))
        topSky.anchorPoint = CGPoint(x: 0.5, y: 1)
        
        topSky.position = CGPoint(x: frame.midX, y: frame.height)
        bottomSky.position = CGPoint(x: frame.midX, y: bottomSky.frame.height / 2)
        
        addChild(topSky)
        addChild(bottomSky)
        
        bottomSky.zPosition = -40
        topSky.zPosition = -40
    }
    
    func createBackground() {
        // In the assets for this game it's a set of distant mountains and clouds with a faint blue color, but we can't just add this to the game using a sprite node. The reason is simple: while the sky is just two fixed colors, the background mountains need to scroll. Making the mountains scroll is easy enough, but what's harder is ensuring the mountains don't just scroll off the screen and leave nothing behind. What we really want to happen is to have mountains scroll to the left forever, looping infinitely.This is accomplished by creating two sets of mountains, both moving left. When one moves off the screen completely we're going to move it way over to the other side of the screen so that it can carry on moving. With two sets of mountains in place, this means there'll be a seamless, never-ending mountain range in the background.
        
        let backgroundTexture = SKTexture(imageNamed: "background")
        
        for i in 0 ... 1 {
            let background = SKSpriteNode(texture: backgroundTexture)
            background.zPosition = -30
            background.anchorPoint = CGPoint.zero
            background.position = CGPoint(x: (backgroundTexture.size().width * CGFloat(i)) - CGFloat(1 * i), y: 100)
            //  The first time the loop goes around X will be 0, and the second time the loop goes around X will be the width of the texture minus 1 to avoid any tiny little gaps in the mountains.
            
            addChild(background)
            
            let moveLeft = SKAction.moveBy(x: -backgroundTexture.size().width, y: 0, duration: 20)
            let moveReset = SKAction.moveBy(x: backgroundTexture.size().width, y: 0, duration: 0)
            let moveLoop = SKAction.sequence([moveLeft, moveReset])
            let moveForever = SKAction.repeatForever(moveLoop)
            
            background.run(moveForever)
        }
    }
    
    func createGround() {
        let groundTexture = SKTexture(imageNamed: "ground")
        
        for i in 0 ... 1 {
            let ground = SKSpriteNode(texture: groundTexture)
            ground.zPosition = -10
            ground.position = CGPoint(x: (groundTexture.size().width / 2.0 + (groundTexture.size().width * CGFloat(i))), y: groundTexture.size().height / 2)
            
            ground.physicsBody = SKPhysicsBody(texture: ground.texture!, size: ground.texture!.size())
            ground.physicsBody?.isDynamic = false
            // That sets up pixel-perfect collision for the ground sprites, but makes them non-dynamic – that is, they will respond to physics in the game so that the plane hits the ground, but they won't get moved by the physics. Without this line the ground would drop off the screen thanks to gravity.
            
            addChild(ground)
            
            let moveLeft = SKAction.moveBy(x: -groundTexture.size().width, y: 0, duration: 5)
            let moveReset = SKAction.moveBy(x: groundTexture.size().width, y: 0, duration: 0)
            let moveLoop = SKAction.sequence([moveLeft, moveReset])
            let moveForever = SKAction.repeatForever(moveLoop)
            
            ground.run(moveForever)
        }
    }
    
    func createRocks() {
        // 1. Create top and bottom rock sprites. They are both the same graphic, but we're going to rotate the top one and flip it horizontally so that the two rocks form a spiky death for the player.
        // 2. Create a third sprite that is a large red rectangle. This will be positioned just after the rocks and will be used to track when the player has passed through the rocks safely – if they touch that red rectangle, they should score a point. (Don't worry, we'll make it invisible later!)
        // 3. Use the GKRandomDistribution class in GameplayKit to generate a random number in a range. This will be used to determine where the safe gap in the rocks should be.
        // 4. Position the rocks just off the right edge of the screen, then animate them across to the left edge. When they are safely off the left edge, remove them from the game.
    
        // 1
        let rockTexture = SKTexture(imageNamed: "rock")
        let topRock = SKSpriteNode(texture: rockTexture)
        
        topRock.physicsBody = SKPhysicsBody(texture: rockTexture, size: rockTexture.size())
        topRock.physicsBody?.isDynamic = false
        
        topRock.zRotation = CGFloat.pi // This rotates it by 180 deg
        topRock.xScale = -1.0 // This flips the image long side to make the topRock a reflection of the bottomRock
        
        let bottomRock = SKSpriteNode(texture: rockTexture)
        bottomRock.physicsBody = SKPhysicsBody(texture: rockTexture, size: rockTexture.size())
        bottomRock.physicsBody?.isDynamic = false
        
        topRock.zPosition = -20
        bottomRock.zPosition = -20
        
        // 2
        let rockCollision = SKSpriteNode(color: UIColor.clear, size: CGSize(width: 32, height: frame.height))
        rockCollision.name = "scoreDetect"
        rockCollision.physicsBody = SKPhysicsBody(rectangleOf: rockCollision.size)
        rockCollision.physicsBody?.isDynamic = false
        
        addChild(topRock)
        addChild(bottomRock)
        addChild(rockCollision)
        
        // 3
        let xPosition = frame.width + topRock.frame.width
        
        let max = Int(frame.height / 3)
        let rand = GKRandomDistribution(lowestValue: -100, highestValue: max)
        let yPosition = CGFloat(rand.nextInt())
        
        // this next value affects the width of the gap between rocks make it smaller to make your game harder
        
        let rockDistance: CGFloat = 70
        
        // 4
        topRock.position = CGPoint(x: xPosition, y: yPosition + topRock.size.height + rockDistance)
        bottomRock.position = CGPoint(x: xPosition, y: yPosition - rockDistance)
        rockCollision.position = CGPoint(x: xPosition + rockCollision.size.width * 2, y: frame.midY)
        
        let endPosition = frame.width + (topRock.frame.width * 2)
        
        let moveAction = SKAction.moveBy(x: -endPosition, y: 0, duration: 6.2)
        let moveSequence = SKAction.sequence([moveAction, SKAction.removeFromParent()])
        topRock.run(moveSequence)
        bottomRock.run(moveSequence)
        rockCollision.run(moveSequence)
    }
    
    func startRocks() {
        let create = SKAction.run { [unowned self] in
            self.createRocks()
        } // why do i need the self here? can't I just do create = SKAction.run(createRocks)?
        
        let wait = SKAction.wait(forDuration: 3)
        let sequence = SKAction.sequence([create, wait])
        let repeatForever = SKAction.repeatForever(sequence)
        
        run(repeatForever)
    }
    
    func createScore() {
        gameScore = SKLabelNode(fontNamed: "Optima-ExtraBlack")
        gameScore.horizontalAlignmentMode = .right
        gameScore.position = CGPoint(x: frame.maxX - 20, y: frame.maxY - 40)
        gameScore.fontSize = 24
        gameScore.text = "Score: 0"
        gameScore.fontColor = UIColor.black
        addChild(gameScore)
    }
    
    func didBegin(_ contact: SKPhysicsContact) {
        
        if contact.bodyA.node?.name == "ScoreDetect" || contact.bodyB.node?.name == "scoreDetect" {
            if contact.bodyA.node == player {
                contact.bodyB.node?.removeFromParent()
            } else {
                contact.bodyA.node?.removeFromParent()
            }
            
            let sound = SKAction.playSoundFileNamed("coin.wav", waitForCompletion: false)
            run(sound)
            score += 10
            
            return // this is needed because if the player collides with anything else we want to destroy them. This just means, "you hit something safe; don't continue in this method."
        }
        
        
        if contact.bodyA.node == player || contact.bodyB.node == player {
            // Because the player's physics are configured to report back contact with absolutely everything, and because we just made didBegin() exit if the player touches a scoring rectangle, we can be sure that any code coming after our previous additions will only be executed if the player hit a rock or the ground.
            if let explosion = SKEmitterNode(fileNamed: "PlayerExplosion") {
                explosion.position = player.position
                addChild(explosion)
            }

            let sound = SKAction.playSoundFileNamed("explosion.wav", waitForCompletion: false)
            
            run(sound)
            
            gameOver.alpha = 1
            gameState = .dead
            backgroundMusic.run(SKAction.stop())
            
            player.removeFromParent()
            speed = 0
        }
    }
    
    func createLogo() {
        logo = SKSpriteNode(imageNamed: "logo")
        logo.position = CGPoint(x: frame.midX, y: frame.midY)
        addChild(logo)
        
        gameOver = SKSpriteNode(imageNamed: "gameover")
        gameOver.position = CGPoint(x: frame.midX, y: frame.midY)
        gameOver.alpha = 0
        addChild(gameOver)
    }
}

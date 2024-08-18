import AVFoundation
import GoogleMobileAds
import Localize_Swift
import SnapKit
import SpriteKit
import SwiftyButton
import Then
import UIKit

class GameViewController: UIViewController {
    // MARK: Properties

    // The scene draws the tiles and cookie sprites, and handles swipes.
    var scene: GameScene!
    var level: Level!

    var movesLeft = 0
    var score = 0
    var tapGestureRecognizer: UITapGestureRecognizer!
    var currentLevelNum = 0

    var timer = Timer()

    lazy var gameOverPanel = UIImageView().then { imageView in
        imageView.contentMode = .scaleAspectFit
    }

    lazy var levelLabel = UILabel().then { label in
        label.font = UIFont.boldSystemFont(ofSize: 20)
        label.textAlignment = .center
        label.text = "\("Level".localized())\n0 / \(numLevels)"
        label.numberOfLines = 2
    }

    lazy var musicLabel = UILabel().then { label in
        label.font = UIFont.boldSystemFont(ofSize: 20)
        label.textAlignment = .center
        label.text = "\("Music".localized())"
        label.numberOfLines = 1
    }

    lazy var musicSwitch = UISwitch().then { s in
        s.addTarget(self, action: #selector(musicSwitchChange(_:)), for: .valueChanged)
        s.setOn(true, animated: true)
    }

    lazy var targetLabel = UILabel().then { label in
        label.font = UIFont.boldSystemFont(ofSize: 20)
        label.textAlignment = .center
        label.text = "\("Target".localized())\n999"
        label.numberOfLines = 2
    }

    lazy var movesLabel = UILabel().then { label in
        label.font = UIFont.boldSystemFont(ofSize: 20)
        label.textAlignment = .center
        label.text = "\("Moves".localized())\n999"
        label.numberOfLines = 2
    }

    lazy var scoreLabel = UILabel().then { label in
        label.font = UIFont.boldSystemFont(ofSize: 20)
        label.textAlignment = .center
        label.text = "\("Score".localized())\n0"
        label.numberOfLines = 2
    }

    lazy var shuffleButton = PressableButton().then { button in
        button.colors = .init(button: UIColor.shuffleButtonColor, shadow: .shuffleButtonShadowColor)
        button.setTitle("Shuffle".localized(), for: .normal)
        button.titleLabel?.font = UIFont.boldSystemFont(ofSize: 30)
        button.shadowHeight = 3
        button.cornerRadius = 8
        button.addTarget(self, action: #selector(shuffleButtonTapped(_:)), for: .touchUpInside)
    }

    lazy var moreAppsButton = PressableButton().then { button in
        button.colors = .init(button: UIColor.shuffleButtonColor, shadow: .shuffleButtonShadowColor)
        button.setTitle("More Apps".localized(), for: .normal)
        button.titleLabel?.font = UIFont.boldSystemFont(ofSize: 30)
        button.shadowHeight = 3
        button.cornerRadius = 8
        button.addTarget(self, action: #selector(moreAppsButtonTapped(_:)), for: .touchUpInside)
    }

    lazy var tryAgainButton = PressableButton().then { button in
        button.colors = .init(button: UIColor.tryAgainButtonColor, shadow: .tryAgainButtonShadowColor)
        button.setTitle("Try Again".localized(), for: .normal)
        button.titleLabel?.font = UIFont.boldSystemFont(ofSize: 30)
        button.shadowHeight = 3
        button.cornerRadius = 8
        button.addTarget(self, action: #selector(tryAgainButtonTapped(_:)), for: .touchUpInside)
    }

    lazy var continueButton = PressableButton().then { button in
        button.colors = .init(button: UIColor.continueButtonColor, shadow: .continueButtonShadowColor)
        button.setTitle("Continue".localized(), for: .normal)
        button.titleLabel?.font = UIFont.boldSystemFont(ofSize: 30)
        button.shadowHeight = 3
        button.cornerRadius = 8
        button.addTarget(self, action: #selector(continueButtonTapped(_:)), for: .touchUpInside)
    }

    lazy var bannerView: GADBannerView = {
        let bannerView = GADBannerView()
        bannerView.adUnitID = Constants.bannerAdUnitID
        bannerView.rootViewController = self
        bannerView.load(GADRequest())
        return bannerView
    }()

    override func viewDidLoad() {
        super.viewDidLoad()

        timer = Timer.scheduledTimer(timeInterval: 6.0, target: self, selector: #selector(fireTimer), userInfo: nil, repeats: true)

        // Setup view with level 1
        setupLevel(number: currentLevelNum)

        // Start the background music.
        playBackgroundMusic(filename: "Chinatown.mp3", repeatForever: true)

        view.addSubview(gameOverPanel)
        view.addSubview(levelLabel)
        view.addSubview(musicLabel)
        view.addSubview(musicSwitch)
        view.addSubview(targetLabel)
        view.addSubview(movesLabel)
        view.addSubview(scoreLabel)
        view.addSubview(shuffleButton)
        view.addSubview(moreAppsButton)
        view.addSubview(tryAgainButton)
        view.addSubview(continueButton)
        tryAgainButton.isHidden = true
        continueButton.isHidden = true

        gameOverPanel.snp.makeConstraints { make in
            make.centerX.equalToSuperview()
            make.centerY.equalToSuperview().offset(214)
        }

        levelLabel.snp.makeConstraints { make in
            if Constants.isIPhone {
                if let topInset = UIApplication.shared.delegate?.window??.safeAreaInsets.top, topInset <= 24 {
                    make.top.equalToSuperview().offset(20)
                    make.centerX.equalToSuperview().offset(-120)
                } else {
                    make.top.equalToSuperview().offset(50)
                    make.centerX.equalToSuperview().offset(-140)
                }
            } else {
                make.top.equalToSuperview().offset(50)
                make.centerX.equalToSuperview().offset(-180)
            }
        }

        musicLabel.snp.makeConstraints { make in
            if Constants.isIPhone {
                if let topInset = UIApplication.shared.delegate?.window??.safeAreaInsets.top, topInset <= 24 {
                    make.top.equalToSuperview().offset(20 + 60)
                    make.centerX.equalToSuperview().offset(-120)
                } else {
                    make.top.equalToSuperview().offset(50 + 60)
                    make.centerX.equalToSuperview().offset(-140)
                }
            } else {
                make.top.equalToSuperview().offset(50 + 60)
                make.centerX.equalToSuperview().offset(-180)
            }
        }

        musicSwitch.snp.makeConstraints { make in
            if Constants.isIPhone {
                if let topInset = UIApplication.shared.delegate?.window??.safeAreaInsets.top, topInset <= 24 {
                    make.top.equalToSuperview().offset(20 + 90)
                    make.centerX.equalToSuperview().offset(-120)
                } else {
                    make.top.equalToSuperview().offset(50 + 90)
                    make.centerX.equalToSuperview().offset(-140)
                }
            } else {
                make.top.equalToSuperview().offset(50 + 90)
                make.centerX.equalToSuperview().offset(-180)
            }
        }

        movesLabel.snp.makeConstraints { make in
            if Constants.isIPhone {
                if let topInset = UIApplication.shared.delegate?.window??.safeAreaInsets.top, topInset <= 24 {
                    make.top.equalToSuperview().offset(20)
                } else {
                    make.top.equalToSuperview().offset(50)
                }
            } else {
                make.top.equalToSuperview().offset(50)
            }
            make.centerX.equalToSuperview().offset(0)
        }

        targetLabel.snp.makeConstraints { make in
            if Constants.isIPhone {
                if let topInset = UIApplication.shared.delegate?.window??.safeAreaInsets.top, topInset <= 24 {
                    make.top.equalToSuperview().offset(20)
                    make.centerX.equalToSuperview().offset(120)
                } else {
                    make.top.equalToSuperview().offset(50)
                    make.centerX.equalToSuperview().offset(140)
                }
            } else {
                make.top.equalToSuperview().offset(50)
                make.centerX.equalToSuperview().offset(180)
            }
        }

        scoreLabel.snp.makeConstraints { make in
            if Constants.isIPhone {
                if let topInset = UIApplication.shared.delegate?.window??.safeAreaInsets.top, topInset <= 24 {
                    make.top.equalToSuperview().offset(20 + 60)
                    make.centerX.equalToSuperview().offset(120)
                } else {
                    make.top.equalToSuperview().offset(50 + 60)
                    make.centerX.equalToSuperview().offset(140)
                }
            } else {
                make.top.equalToSuperview().offset(50 + 60)
                make.centerX.equalToSuperview().offset(180)
            }
        }

        shuffleButton.snp.makeConstraints { make in
            make.centerX.equalToSuperview()
            if Constants.isIPhone {
                if let topInset = UIApplication.shared.delegate?.window??.safeAreaInsets.top, topInset > 24 {
                    make.bottom.equalToSuperview().offset(-160)
                } else {
                    make.bottom.equalToSuperview().offset(-100)
                }
            } else {
                make.bottom.equalToSuperview().offset(-200)
            }
            make.width.equalTo(180)
            make.height.equalTo(40)
        }

        moreAppsButton.snp.makeConstraints { make in
            make.centerX.equalToSuperview()
            make.top.equalTo(shuffleButton.snp.bottom).offset(10)
            make.width.equalTo(180)
            make.height.equalTo(40)
        }

        continueButton.snp.makeConstraints { make in
            make.centerX.equalToSuperview()
            make.bottom.equalTo(shuffleButton.snp.top).offset(-50)
            make.width.equalTo(200)
            make.height.equalTo(50)
        }

        tryAgainButton.snp.makeConstraints { make in
            make.centerX.equalToSuperview()
            make.bottom.equalTo(continueButton.snp.top).offset(-10)
            make.width.equalTo(200)
            make.height.equalTo(50)
        }

        view.addSubview(bannerView)
        bannerView.snp.makeConstraints { make in
            make.height.equalTo(50)
            make.width.equalToSuperview()
            make.bottom.equalTo(view.safeAreaLayoutGuide)
            make.centerX.equalToSuperview()
        }
    }

    func setupLevel(number levelNumber: Int) {
        let skView = view as! SKView
        skView.isMultipleTouchEnabled = false

        // Create and configure the scene.
        scene = GameScene(size: skView.bounds.size)
        scene.scaleMode = .aspectFill

        // Setup the level.
        level = Level(filename: "Level_\(levelNumber)")
        scene.level = level

        scene.addTiles()
        scene.swipeHandler = handleSwipe

        gameOverPanel.isHidden = true
        shuffleButton.isHidden = true

        // Present the scene.
        skView.presentScene(scene)

        // Start the game.
        beginGame()
    }

    // MARK: actions

    @objc func shuffleButtonTapped(_ sender: UIButton) {
        shuffle()
        decrementMoves()
    }

    @objc func moreAppsButtonTapped(_ sender: UIButton) {
        let moreAppsViewController = MoreAppsViewController()
        if let rootViewController = view.window?.rootViewController { rootViewController.present(moreAppsViewController, animated: true)
        }
    }

    @objc func tryAgainButtonTapped(_ sender: UIButton) {
        if musicSwitch.isOn {
            if currentLevelNum % 3 == 0 {
                playBackgroundMusic(filename: "Chinatown.mp3", repeatForever: true)
            } else if currentLevelNum % 3 == 1 {
                playBackgroundMusic(filename: "Colorful.mp3", repeatForever: true)
            } else {
                playBackgroundMusic(filename: "glitter-blast.mp3", repeatForever: true)
            }
        }

        gameOverPanel.isHidden = true
        tryAgainButton.isHidden = true
        continueButton.isHidden = true
        scene.isUserInteractionEnabled = true

        setupLevel(number: currentLevelNum)

        timer.invalidate()
        timer = Timer.scheduledTimer(timeInterval: 6.0, target: self, selector: #selector(fireTimer), userInfo: nil, repeats: true)
        let swapSet = level.possibleSwaps
        for swap in swapSet {
            let elementA = swap.cookieA
            let elementB = swap.cookieB
            elementA.sprite?.removeAction(forKey: "hintAction")
            elementA.sprite?.isHidden = false
            elementB.sprite?.removeAction(forKey: "hintAction")
            elementB.sprite?.isHidden = false
        }
    }

    @objc func continueButtonTapped(_ sender: UIButton) {
        if musicSwitch.isOn {
            if currentLevelNum % 3 == 0 {
                playBackgroundMusic(filename: "Chinatown.mp3", repeatForever: true)
            } else if currentLevelNum % 3 == 1 {
                playBackgroundMusic(filename: "Colorful.mp3", repeatForever: true)
            } else {
                playBackgroundMusic(filename: "glitter-blast.mp3", repeatForever: true)
            }
        }

        gameOverPanel.isHidden = true
        tryAgainButton.isHidden = true
        continueButton.isHidden = true
        scene.isUserInteractionEnabled = true

        setupLevel(number: currentLevelNum)

        timer.invalidate()
        timer = Timer.scheduledTimer(timeInterval: 6.0, target: self, selector: #selector(fireTimer), userInfo: nil, repeats: true)
        let swapSet = level.possibleSwaps
        for swap in swapSet {
            let elementA = swap.cookieA
            let elementB = swap.cookieB
            elementA.sprite?.removeAction(forKey: "hintAction")
            elementA.sprite?.isHidden = false
            elementB.sprite?.removeAction(forKey: "hintAction")
            elementB.sprite?.isHidden = false
        }
    }

    @objc func musicSwitchChange(_ sender: UISwitch) {
        if sender.isOn {
            if currentLevelNum % 3 == 0 {
                playBackgroundMusic(filename: "Chinatown.mp3", repeatForever: true)
            } else if currentLevelNum % 3 == 1 {
                playBackgroundMusic(filename: "Colorful.mp3", repeatForever: true)
            } else {
                playBackgroundMusic(filename: "glitter-blast.mp3", repeatForever: true)
            }
        } else {
            backgroundMusicPlayer.stop()
        }
    }

    @objc func fireTimer() {
        let swapSet = level.possibleSwaps
        let swap = swapSet.randomElement()
        if let elementA = swap?.cookieA, let elementB = swap?.cookieB {
            let blinkTimes = 10.0
            let duration = 3.0
            let blinkAction = SKAction.customAction(withDuration: duration) { node, elapsedTime in
                let slice = duration / blinkTimes
                let remainder = Double(elapsedTime).truncatingRemainder(
                    dividingBy: slice)
                node.isHidden = remainder > slice / 2
            }
            let setHidden = SKAction.run {
                elementA.sprite?.isHidden = false
                elementB.sprite?.isHidden = false
            }
            elementA.sprite?.run(SKAction.sequence([blinkAction, setHidden]), withKey: "hintAction")
            elementB.sprite?.run(SKAction.sequence([blinkAction, setHidden]), withKey: "hintAction")
        }
        print("Timer fired!")
    }

    // MARK: View Controller Functions

    override var prefersStatusBarHidden: Bool {
        return true
    }

    override var shouldAutorotate: Bool {
        return true
    }

    func beginGame() {
        movesLeft = level.maximumMoves
        score = 0
        updateLabels()
        level.resetComboMultiplier()
        scene.animateBeginGame {
            self.shuffleButton.isHidden = false
        }
        shuffle()
    }

    func shuffle() {
        scene.removeAllCookieSprites()
        let newCookies = level.shuffle()
        scene.addSprites(for: newCookies)
    }

    override var supportedInterfaceOrientations: UIInterfaceOrientationMask {
        return [.portrait, .portraitUpsideDown]
    }

    func handleSwipe(_ swap: Swap) {
        view.isUserInteractionEnabled = false

        if level.isPossibleSwap(swap) {
            level.performSwap(swap)
            timer.invalidate()
            timer = Timer.scheduledTimer(timeInterval: 6.0, target: self, selector: #selector(fireTimer), userInfo: nil, repeats: true)
            let swapSet = level.possibleSwaps
            for swap in swapSet {
                let elementA = swap.cookieA
                let elementB = swap.cookieB
                elementA.sprite?.removeAction(forKey: "hintAction")
                elementA.sprite?.isHidden = false
                elementB.sprite?.removeAction(forKey: "hintAction")
                elementB.sprite?.isHidden = false
            }
            scene.animate(swap, completion: handleMatches)
        } else {
            scene.animateInvalidSwap(swap) {
                self.view.isUserInteractionEnabled = true
            }
        }
    }

    func handleMatches() {
        let chains = level.removeMatches()
        if chains.count == 0 {
            beginNextTurn()
            return
        }

        scene.animateMatchedCookies(for: chains) {
            for chain in chains {
                self.score += chain.score
            }

            self.updateLabels()
            let columns = self.level.fillHoles()
            self.scene.animateFallingCookies(in: columns) {
                let columns = self.level.topUpCookies()
                self.scene.animateNewCookies(in: columns) {
                    self.handleMatches()
                }
            }
        }
    }

    func beginNextTurn() {
        level.detectPossibleSwaps()
        view.isUserInteractionEnabled = true
        decrementMoves()
    }

    func updateLabels() {
        levelLabel.text = "\("Level".localized())\n\(currentLevelNum + 1)  / \(numLevels)"
        targetLabel.text = "\("Target".localized())\n\(level.targetScore)"
        movesLabel.text = "\("Moves".localized())\n\(movesLeft)"
        scoreLabel.text = "\("Score".localized())\n\(score)"
    }

    func decrementMoves() {
        movesLeft -= 1
        updateLabels()
        if score >= level.targetScore {
            if currentLevelNum + 1 < numLevels {
                gameOverPanel.image = UIImage(named: "LevelComplete")
            } else {
                gameOverPanel.image = UIImage(named: "final")
            }
            currentLevelNum = currentLevelNum + 1 < numLevels ? currentLevelNum + 1 : 0
            showGameOver()
        } else if movesLeft <= 0 {
            gameOverPanel.image = UIImage(named: "GameOver")
            showGameLose()
        }
    }

    func showGameOver() {
        timer.invalidate()
        DispatchQueue.main.async {
            self.gameOverPanel.snp.remakeConstraints { make in
                make.centerX.equalToSuperview()
                if self.currentLevelNum != 0 {
                    make.centerY.equalToSuperview().offset((214 + self.view.bounds.height) / 2)
                } else {
                    make.centerY.equalToSuperview().offset((323 + self.view.bounds.height) / 2)
                }
            }
            self.gameOverPanel.isHidden = false
            self.view.layoutIfNeeded()
            UIView.animate(withDuration: 0.8) {
                self.gameOverPanel.snp.remakeConstraints { make in
                    make.centerX.equalToSuperview()
                    make.centerY.equalToSuperview()
                }
                self.view.layoutIfNeeded()
            }
        }

        scene.isUserInteractionEnabled = false
        shuffleButton.isHidden = true

        scene.animateGameOver {
            self.tapGestureRecognizer = UITapGestureRecognizer(target: self, action: #selector(self.hideGameOver))
            self.view.addGestureRecognizer(self.tapGestureRecognizer)
        }
    }

    func showGameLose() {
        #if !targetEnvironment(macCatalyst)
            GADInterstitialAd.load(withAdUnitID: Constants.interstitialAdID, request: GADRequest()) { ad, error in
                if let error = error {
                    print("Failed to load interstitial ad with error: \(error.localizedDescription)")
                    return
                }
                if let ad = ad {
                    if let rootViewController = self.view?.window?.rootViewController {
                        ad.present(fromRootViewController: rootViewController)
                    }
                } else {
                    print("interstitial Ad wasn't ready")
                }
            }
        #else
            let moreAppsViewController = MoreAppsViewController()
            if let rootViewController = view.window?.rootViewController { rootViewController.present(moreAppsViewController, animated: true)
            }
        #endif

        timer.invalidate()
        DispatchQueue.main.async {
            self.gameOverPanel.snp.remakeConstraints { make in
                make.centerX.equalToSuperview()
                if self.currentLevelNum != 0 {
                    make.centerY.equalToSuperview().offset((214 + self.view.bounds.height) / 2)
                } else {
                    make.centerY.equalToSuperview().offset((323 + self.view.bounds.height) / 2)
                }
            }
            self.gameOverPanel.isHidden = false
            self.view.layoutIfNeeded()
            UIView.animate(withDuration: 0.8, animations: {
                self.gameOverPanel.snp.remakeConstraints { make in
                    make.centerX.equalToSuperview()
                    make.centerY.equalToSuperview().offset(-100)
                }
                self.view.layoutIfNeeded()
            }) { _ in
                self.tryAgainButton.isHidden = false
            }
        }

        scene.isUserInteractionEnabled = false
        shuffleButton.isHidden = true
    }

    @objc func hideGameOver() {
        if musicSwitch.isOn {
            if currentLevelNum % 3 == 0 {
                playBackgroundMusic(filename: "Chinatown.mp3", repeatForever: true)
            } else if currentLevelNum % 3 == 1 {
                playBackgroundMusic(filename: "Colorful.mp3", repeatForever: true)
            } else {
                playBackgroundMusic(filename: "glitter-blast.mp3", repeatForever: true)
            }
        }
        view.removeGestureRecognizer(tapGestureRecognizer)
        tapGestureRecognizer = nil

        gameOverPanel.isHidden = true
        scene.isUserInteractionEnabled = true

        setupLevel(number: currentLevelNum)

        timer.invalidate()
        timer = Timer.scheduledTimer(timeInterval: 6.0, target: self, selector: #selector(fireTimer), userInfo: nil, repeats: true)
        let swapSet = level.possibleSwaps
        for swap in swapSet {
            let elementA = swap.cookieA
            let elementB = swap.cookieB
            elementA.sprite?.removeAction(forKey: "hintAction")
            elementA.sprite?.isHidden = false
            elementB.sprite?.removeAction(forKey: "hintAction")
            elementB.sprite?.isHidden = false
        }
    }
}

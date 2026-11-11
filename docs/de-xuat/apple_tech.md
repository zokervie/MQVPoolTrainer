# Apple-platform and on-device AI technologies for ZokerPoolTrainer (state as of Nov 2026)

Context: today is 2026-11-11. iOS 27 shipped on 14 Sep 2026 ([MacRumors](https://macrumors.com/2026/09/13/ios-27-release-date-new-features/)). WWDC26 was 9 Jun 2026 ([iClarified](https://www.iclarified.com/101143/apple-unveils-new-ai-frameworks-and-agentic-coding-in-xcode-27)). Items marked **[not re-verified]** come from Apple doc URLs I did not fetch this session, or from pre-mid-2025 knowledge. Treat them as needing a check.

## 1. Rendering: SceneKit status and Apple's direction (RealityKit, Metal 4, MetalFX, Game Mode)

### Takeaway
SceneKit was soft-deprecated on all platforms at WWDC25 and is in maintenance mode, with only critical bug fixes. It is not being removed, so the current UIKit+SceneKit app keeps working. Apple points new and major work to RealityKit, which now supports custom post-processing on iOS. Metal 4 and MetalFX, including frame interpolation, are the high-end path. Because the physics engine is our own C++ core, the renderer could be swapped later without touching it. Migration is medium-cost, optional, and not urgent.

### Cited Findings
- "Apple is officially deprecating SceneKit across all platforms… This is a soft deprecation, meaning that existing applications that use SceneKit will continue to work. However, if you're planning a new app or a significant update, SceneKit is not recommended." — [WWDC25 session 288 "Bring your SceneKit project to RealityKit"](https://developer.apple.com/videos/play/wwdc2025/288/)
- "SceneKit is now entering maintenance mode. Apple will only fix critical bugs… At this time, there's no plan to hard deprecate SceneKit, and Apple will give developers ample notice." — [WWDC25-288](https://developer.apple.com/videos/play/wwdc2025/288/)
- Apple ships a migration guide, "Bringing your SceneKit projects to RealityKit". — [Apple docs](https://developer.apple.com/documentation/realitykit/bringing-your-scenekit-projects-to-realitykit.md)
- RealityKit runs on iOS, iPadOS, macOS, visionOS and, new in 2025, tvOS, with one codebase. Content renders through SwiftUI `RealityView`, and behavior is built from ECS components (physics, particles, portals). — [WWDC25-288](https://developer.apple.com/videos/play/wwdc2025/288/)
- New in 2025: custom post-processing effects on RealityViews on iOS, iPadOS, macOS and tvOS, through `PostProcessEffect` and `content.renderingEffects.customPostProcessing`. SceneKit-style one-flag bloom is "deliberately not available". You build it with Metal Performance Shaders instead. — [WWDC25-288](https://developer.apple.com/videos/play/wwdc2025/288/)
- WWDC26 game items: Reality Composer Pro 3 (live previews), Game Porting Toolkit 4 with Metal agent skills, Managed Background Assets (download only the asset packs a player needs), and official Unity plug-ins for StoreKit and Background Assets. — [iClarified WWDC26](https://www.iclarified.com/101143/apple-unveils-new-ai-frameworks-and-agentic-coding-in-xcode-27)
- iOS 27 sessions include "Build real-time neural rendering pipelines with Metal", "Find and fix performance issues in your Metal games", "Make your game great with touch", and "Optimize custom ML operations with Metal tensors". — [Apple iOS 27 what's new](https://developer.apple.com/ios/whats-new/)
- Metal 4 (WWDC25) added MetalFX Frame Interpolation and denoising alongside the existing MetalFX upscaling. — [WWDC25 session 211](https://developer.apple.com/videos/play/wwdc2025/211); [Engadget](https://www.engadget.com/gaming/metal-4-for-macos-tahoe-26-introduces-new-gaming-features-like-frame-interpolation-183247623.html); API: [MTLFXFrameInterpolatorDescriptor](https://developer.apple.com/documentation/metalfx/mtlfxframeinterpolatordescriptor.md)
- A developer reports that MetalFX frame interpolation costs about 18 ms per frame in their game on iPhone, and about 11 ms even in a triangle demo. That is too slow for 120 Hz on iPhone today. — [Apple Developer Forums thread 853871](https://developer.apple.com/forums/thread/853871)
- Game Mode (iOS/iPadOS 18+) turns on automatically when a game goes full screen. It gives the game "the highest priority access to your CPU and GPU", reduces background work, and raises the Bluetooth polling rate for controllers and AirPods. — [Apple Support 105118](https://support.apple.com/105118)
- [not re-verified] Adaptive and ProMotion frame pacing on iOS use `CADisplayLink.preferredFrameRateRange` and need `CADisableMinimumFrameDurationOnPhone` in Info.plist for 120 Hz. SceneKit exposes `preferredFramesPerSecond` on SCNView. — [CADisplayLink docs](https://developer.apple.com/documentation/quartzcore/cadisplaylink)

### Inferences
- **Low risk to stay on SceneKit through 2027.** Soft deprecation means no new features and few optimizations, but no removal date. The physics core is in C++, so SceneKit is "just a view". A thin render-abstraction layer (table, balls, cue, cameras, trails) keeps a future RealityKit or Metal port contained.
- **RealityKit benefits:** future-proofing, a shared path with visionOS (a spatial or tabletop billiards trainer on Vision Pro), and post-processing hooks for cinematic replays. **Costs:** RealityKit is SwiftUI- and ECS-centric, while the app is UIKit (hosting a RealityView in a UIHostingController is possible). Custom materials and line rendering for aim and prediction lines need rework. Bloom and SSAO-style effects must be rebuilt by hand. CI snapshot (G1 probe) baselines would all change.
- **Metal direct** is only worth it for a "showcase" renderer (for example, ray-traced ball reflections in replay). MetalFX upscaling could render replays and highlight export at lower internal resolution on older iPads. Frame interpolation is not yet practical on iPhone, per the forum report.
- **Game Mode** applies automatically to full-screen games. Correctly flagging the app as a game (LSApplicationCategoryType = games, **[not re-verified]**) likely matters both for Game Mode and for appearing in the Games app.

### Gaps
- No Apple statement found on SceneKit changes in iOS 27, for example further deprecation warnings. The iOS 27 what's-new page doesn't mention SceneKit or RealityKit.
- No confirmed list of RealityKit iOS 27 additions (WWDC26 RealityKit session not fetched).
- The exact Info.plist keys that make an app eligible for Game Mode were not verified.

## 2. Camera/AR: ARKit, Vision, LiDAR — filming a real table, importing layouts, AR aim overlay

### Takeaway
Importing a real layout from a photo is proven feasible and already shipping in competitors. AimPool detects balls from a photo using 4-corner table calibration, then has the user confirm or edit each ball. DrillRoom tracks drills live from a tripod-mounted iPhone. Vision has a built-in parabolic-trajectory detector, which doesn't suit rolling balls (ball paths on a table aren't parabolic), and a 3D body pose request useful for analyzing a player's stroke posture. A live handheld AR aim overlay on a physical table is technically possible with ARKit plane and LiDAR anchoring. It is the hardest and least robust option, so it should come last.

### Cited Findings
- AimPool (App Store, iOS 17+): "photograph your table… calibrates the playable table from four corners… Ball detection proposes editable suggestions, and you confirm every ball before the app plans a shot". Photo analysis stays on device. Photo analysis of your own table is behind Premium ($19.99/yr annual or $29.99). It also offers Apple Watch scoring. — [App Store: AimPool](https://apps.apple.com/app/id6789332083)
- DrillRoom uses AI and computer vision on the live video stream. The iPhone or iPad sits on a tripod at least 5 ft high. It works with different table sizes, cloth colors and snooker tables. It couldn't track a full 9-ball rack at the time "without compromising the accuracy". A11 or later is recommended. — [OrangeLoops case study (2021)](https://orangeloops.com/2021/02/drillroom-ai-powered-billiard-training-ios-app/)
- `VNDetectTrajectoriesRequest`: "A request that detects the trajectories of shapes moving along a parabolic path." — [Apple docs](https://developer.apple.com/documentation/vision/vndetecttrajectoriesrequest)
- Vision 3D human body pose detects 17 joints in meters relative to the image and estimates the camera position relative to the person. Vision can take depth data, and "LiDAR enables high accuracy measurement of scene". — [WWDC23-111241 notes](https://wwdcnotes.com/documentation/wwdc23-111241-explore-3d-body-pose-and-person-segmentation-in-vision/); APIs: [VNDetectHumanBodyPose3DRequest](https://developer.apple.com/documentation/vision/vndetecthumanbodypose3drequest.md), Swift [DetectHumanBodyPose3DRequest](https://developer.apple.com/documentation/vision/detecthumanbodypose3drequest.md)
- In iOS 27, Vision OCR and barcode tools can be called directly by the Foundation Models model, and prompts can include images (multimodal). — [Apple iOS 27 what's new](https://developer.apple.com/ios/whats-new/)
- [not re-verified] ARKit world tracking with horizontal plane detection, plus LiDAR scene depth (`ARFrame.sceneDepth`, Pro iPhones and iPad Pro), gives metric anchoring for overlays. — [ARKit docs](https://developer.apple.com/documentation/arkit)

### Inferences
- **Feature "Photo → Simulator layout" (high value, medium effort):** take one top-down photo, have the user tap the 4 pockets or corners for a homography, detect balls (Hough circles or a small Core ML/Create ML object detector), let the user confirm, then rebuild the layout in the C++ engine, so "Analyze this real shot". This matches AimPool's proven UX. The confirm step avoids accuracy problems. It fits the project rule: prediction lines appear only in analysis mode.
- **Stroke analysis from video:** use a tripod side-view, with 2D or 3D body pose for elbow drop, head movement and bridge stability. Cue-tip tracking needs a custom detector. `VNDetectTrajectoriesRequest` is of little use for rolling balls, though possibly for jump shots.
- **Live AR overlay on a physical table:** handheld jitter and occlusion by the player make it fragile. Consider a "tripod mode" with fixed overhead or high angle as v1. A handheld AR overlay could later serve as a premium or experimental feature. An AR aim overlay during real play is effectively an aiming aid, so keep it in an explicit "analysis/practice" mode, consistent with the app's rule.

### Gaps
- No public accuracy benchmarks found for on-device pool ball detection.
- No Apple sample specific to tabletop sports tracking was found.
- Not verified: whether iOS 27 added new Vision requests (for example, generic object tracking improvements).

## 3. On-device AI: Foundation Models, Core AI, Core ML / Create ML — AI coach, drill generation, voice

### Takeaway
The Foundation Models framework (iOS 26+) gives free, offline access to Apple's on-device LLM. It has a small context window (4K tokens), typed output via `@Generable`, and tool calling. That fits an "AI coach" that turns the physics engine's structured miss data into a short natural-language explanation, or generates drill specs as typed structs. iOS 27 (shipped Sep 2026) adds image input, swappable models through a Language Model protocol (Claude, Gemini, others), Private Cloud Compute free for small developers, an Evaluations framework, and the new Core AI framework for custom on-device models.

### Cited Findings
- Foundation Models gives free, offline access to the on-device Apple Intelligence model, with no API key or per-token cost. It uses `LanguageModelSession` with `respond`/`streamResponse`, `@Generable` and `@Guide` for type-checked structured output, and the `Tool` protocol for calling app code. — [Blake Crosley explainer](https://blakecrosley.com/blog/apple-foundation-models-framework)
- On-device context is 4K tokens for prompt plus response, while Private Cloud Compute gets 32K. It requires iOS 26 and an Apple-Intelligence-capable device. Availability is checked with `SystemLanguageModel.default.availability` (`deviceNotEligible`, `appleIntelligenceNotEnabled`, `modelNotReady`). It suits summarization, classification, extraction and structured output, "not open-ended reasoning, world knowledge…". — [Blake Crosley](https://blakecrosley.com/blog/apple-foundation-models-framework)
- Apple Intelligence (and Siri AI) requires iPhone 15 Pro or newer. Siri AI is English-only at launch and not initially in the EU. — [MacRumors iOS 27](https://macrumors.com/2026/09/13/ios-27-release-date-new-features/)
- iOS 27 Foundation Models brings a single Swift API for "any language model, including Apple Foundation Models, cloud models like Claude and Gemini, or any other provider that conforms to the Language Model protocol", plus image input, on-device OCR and barcode tools, and Dynamic Profiles to "swap models, tools, and instructions on the fly". — [Apple iOS 27 what's new](https://developer.apple.com/ios/whats-new/)
- The next-generation Apple Foundation Models are built with Google Gemini. Apps in the Small Business Program with fewer than 2 million first-time downloads can use them on Private Cloud Compute "at no cloud API cost". — [Apple iOS 27 what's new](https://developer.apple.com/ios/whats-new/); [iClarified](https://www.iclarified.com/101143/apple-unveils-new-ai-frameworks-and-agentic-coding-in-xcode-27)
- iOS 27 additions: per-request `toolCallingMode`, `OCRTool`/`BarcodeReaderTool`, `PrivateCloudComputeLanguageModel`, and watchOS 27 support. iOS 26 code runs unchanged. — [Blake Crosley](https://blakecrosley.com/blog/apple-foundation-models-framework)
- New **Evaluations framework** for testing AI features "across dynamic conditions, going beyond what unit tests alone can catch". — [Apple iOS 27 what's new](https://developer.apple.com/ios/whats-new/)
- New **Core AI** framework: "load, specialize, and run AI models entirely on-device" with a memory-safe Swift API, ahead-of-time compilation, zero-copy data paths, and stateful execution. The iOS 27 page does not mention Core ML. — [Apple iOS 27 what's new](https://developer.apple.com/ios/whats-new/)
- App Intents: entity and intent schemas, plus a new View Annotations API, let Siri act on on-screen content. There is also an App Intents Testing framework. — [Apple iOS 27 what's new](https://developer.apple.com/ios/whats-new/)
- Apple newsroom (Sep 2025) showcased third-party apps built on Foundation Models. — [Apple Newsroom](https://www.apple.com/au/newsroom/2025/09/apples-foundation-models-framework-unlocks-new-intelligent-app-experiences/)

### Inferences
- **AI coach "why did I miss?":** the C++ engine already knows the ideal versus actual cut angle, the contact-point error, speed and spin. Pass a compact JSON summary as a tool result or prompt, then return a `@Generable struct MissExplanation { cause, fix, drillSuggestion }`. Responses are deterministic in shape, small enough for 4K tokens, offline and free. Vietnamese language support for the on-device model must be checked (see Gaps). A template-based fallback is needed for devices that aren't eligible (pre-15 Pro, or Apple Intelligence off).
- **Drill generator:** `@Generable` `DrillSpec` (ball positions on a normalized grid, target pocket, success criteria) is validated by the C++ engine before display, which prevents hallucinated impossible layouts.
- **Voice commands:** App Intents ("Start drill 3", "Replay last shot") give Siri and Shortcuts integration. In-app speech uses the Speech framework (**[not re-verified]** new SpeechAnalyzer API in iOS 26).
- **Custom vision models** (ball detector, cue detector) are trained in Create ML or PyTorch, then deployed through Core ML on iOS 26 or Core AI on iOS 27+.
- The Evaluations framework fits the project rule "write tests first". AI coach outputs could be gated in CI (macOS runner).

### Gaps
- Not confirmed: whether the on-device model supports Vietnamese as of iOS 27. Apple Intelligence language list not fetched.
- Parameter count of the on-device model not confirmed from a fetched source.
- Not confirmed: Core AI minimum OS or device, or whether Core ML is being superseded.
- Apple's guidelines for using third-party cloud models (Claude, Gemini) through the protocol, including privacy labels and billing, not researched.

## 4. Audio: PHASE, AVAudioEngine, Core Haptics audio-haptic sync

### Takeaway
All three are mature, long-shipping frameworks with no 2025-26 changes found. The best-value move is to drive both a short AHAP or `CHHapticPattern` and the impact sample from the same physics event (ball-ball and ball-cushion contact velocity) for tight audio-haptic sync. PHASE adds geometry-aware spatial audio, which is useful mainly for replays with AirPods head tracking.

### Cited Findings
- [not re-verified] Core Haptics (iOS 13+) plays custom haptic patterns (AHAP) with synchronized audio resources inside the same pattern on iPhone 8 or later. — [Core Haptics docs](https://developer.apple.com/documentation/corehaptics)
- [not re-verified] PHASE (iOS 15+) is a physical audio spatialization engine with geometry occlusion, sound events and listener/source models. — [PHASE docs](https://developer.apple.com/documentation/phase)
- [not re-verified] AVAudioEngine supports low-latency node graphs, and `AVAudioEnvironmentNode` provides 3D audio. — [AVAudioEngine docs](https://developer.apple.com/documentation/avfaudio/avaudioengine)
- Game Mode raises Bluetooth polling, which lowers AirPods latency in games. — [Apple Support 105118](https://support.apple.com/105118)
- iOS 27 added a "Music Understanding" framework that analyzes audio across six dimensions on device. It is only tangentially relevant, for example for syncing highlight-video music. — [Apple iOS 27 what's new](https://developer.apple.com/ios/whats-new/)

### Inferences
- Map impact energy to the haptic intensity and sharpness parameters and to sample selection or volume. Pre-load sample banks, and trigger audio and haptic from the main-thread event queue using physics-event timestamps. iPad has no Taptic Engine, so iPad relies on audio only.
- Music Understanding could auto-cut highlight videos to the beat. This is low priority.

### Gaps
- No WWDC25 or WWDC26 changes to PHASE or Core Haptics found. I did not search exhaustively.

## 5. Social/online: Game Center and Games app, SharePlay, App Clips, Live Activities/widgets, Apple Watch motion

### Takeaway
The Games app (preinstalled on iOS/iPadOS/macOS 26+) is the biggest free discovery lever. Game Center **Challenges** are built from leaderboards and **Activities** are built for multiplayer, and both surface there. The Apple Watch CMBatchedSensorManager streams 800 Hz accelerometer and 200 Hz device-motion data during a workout session, which is enough to detect cue-stroke start and impact, as Apple demonstrated with a bat-swing example. The App Store competitor AimPool already uses Apple Watch for scoring.

### Cited Findings
- Games app: "pre-installed… on iOS 26, iPadOS 26, and macOS 26, or later". Challenges "turn single-player activities into social experiences… score-based competitions… before time runs out", built from leaderboards. Multiplayer **activities** "promote your game's multiplayer experiences… help players seamlessly invite friends… even across platforms", using Game Center or "your own multiplayer system". Players are auto-notified when a friend beats their score. Games with Game Center and In-App Events are "prominently displayed". There is a new Top Played chart. — [Apple: Introducing the Games app](https://developer.apple.com/games-app/index.html)
- WWDC25 Game Center session covering challenges, activities and the Games app. — [WWDC25 session 214](https://developer.apple.com/videos/play/wwdc2025/214); docs: [Creating engaging challenges from leaderboards](https://developer.apple.com/documentation/gamekit/creating-engaging-challenges-from-leaderboards)
- Game Overlay (in Control Center) is the entry point to Game Mode controls on iOS 18+. — [Apple Support 105118](https://support.apple.com/105118)
- WidgetKit (iOS 27): "widgets can now be customized through App Intents and dynamic styling". — [Apple iOS 27 what's new](https://developer.apple.com/ios/whats-new/)
- Apple Watch `CMBatchedSensorManager`: "800 Hz accelerometer and 200 Hz device motion, compared to 100 Hz with the existing CMMotionManager". It is available on Apple Watch Series 8 and Ultra (and later), and requires an active HealthKit workout session. Apple's example detects swing start (device motion) and the bat-ball impact point (accelerometer). — [WWDC23-10179 notes](https://wwdcnotes.com/documentation/wwdc23-10179-whats-new-in-core-motion/)
- Foundation Models gains watchOS 27 support. — [Blake Crosley](https://blakecrosley.com/blog/apple-foundation-models-framework)
- [not re-verified] SharePlay via the GroupActivities framework (iOS 15+) lets FaceTime participants share an activity and exchange messages. — [GroupActivities docs](https://developer.apple.com/documentation/groupactivities)
- [not re-verified] App Clips (iOS 14+) are lightweight app parts launched from QR or NFC codes, with a size limit (larger limits in recent iOS versions). — [App Clips docs](https://developer.apple.com/documentation/appclip)
- [not re-verified] Live Activities via ActivityKit (iOS 16.1+) appear on the Lock Screen and Dynamic Island, with push updates. — [ActivityKit docs](https://developer.apple.com/documentation/activitykit)

### Inferences
- **Game Center Challenges:** weekly "Drill of the week" leaderboards, for example the fewest attempts to clear a position, turn into friend challenges in the Games app at near-zero cost.
- **Activities:** expose online matches as joinable activities so friends can join from the Games app. Our relay plus Game Center auth fit the "your own multiplayer system" path.
- **SharePlay:** a "watch my replay together" mode, or turn-based play over FaceTime. The deterministic C++ engine means only shot inputs need syncing, not state.
- **App Clip for pool halls:** a QR code on a physical table opens a drill or score sheet without installing the app. This is a club-marketing angle.
- **Live Activities:** show online match turn status or a drill-session timer on the Lock Screen and Dynamic Island.
- **Apple Watch stroke analyzer:** with the watch on the cue arm, 800 Hz detects the moment of tip contact, while 200 Hz attitude gives backswing length, tempo, follow-through and wrist roll. This needs a workout session (for example, an "other" workout type) and a companion watch app. It is unverified on device (project rule). It differentiates the app from AimPool, which only scores on the Watch.

### Gaps
- Exact OS minimums for the Challenges and Activities APIs (likely iOS 26) were not verified from the docs page.
- Not checked: any 2026 (iOS 27) Game Center or Games-app changes. The iOS 27 what's-new page doesn't mention Game Center.
- Not verified: whether CMBatchedSensorManager rates or device list changed after 2023.
- SharePlay, App Clips and ActivityKit 2025-26 changes were not researched.

## 6. Monetization tech: StoreKit 2 and App Store policy for IAP packs

### Takeaway
StoreKit 2 in iOS 18.x and 26 covers everything an IAP-pack model needs. Offer codes now work for consumables and non-consumables (useful for drill and table packs, influencer and club codes). There is also a new `SubscriptionOfferView`, a stable `appTransactionID` per account, and win-back offers for lapsed subscribers. New iOS 27 work is mainly tooling, such as Unity plug-ins.

### Cited Findings
- Offer codes now cover **consumables, non-consumables and non-renewing subscriptions**, redeemed in-app via `offerCodeRedemption` (SwiftUI) or `presentOfferCodeRedeemSheet` (UIKit). This works back to iOS 16.3, and auto-renewable subscriptions back to iOS 14.2. — [WWDC25 session 241](https://developer.apple.com/videos/play/wwdc2025/241/)
- `AppTransaction.appTransactionID` is "a globally unique value for each Apple Account that downloads your app", back-deployed to iOS 15. `originalPlatform` (iOS 18.4) helps when moving from a paid app to free with IAP. — [WWDC25-241](https://developer.apple.com/videos/play/wwdc2025/241/)
- `Transaction.currentEntitlement(for:)` is deprecated as of iOS 18.4. Use `currentEntitlements(for:)` (an async sequence). — [WWDC25-241](https://developer.apple.com/videos/play/wwdc2025/241/)
- New SwiftUI `SubscriptionOfferView`, plus JWS-signed promotional and intro-eligibility purchase options (iOS 15+) signed with the App Store Server Library. Purchase calls need a UI context (`UIViewController`) from iOS 18.2. — [WWDC25-241](https://developer.apple.com/videos/play/wwdc2025/241/)
- The renewal expiration reason (for example, `didNotConsentToPriceIncrease`) is suggested as a moment to "merchandise a win-back offer". Win-back offers were introduced at WWDC24. — [WWDC25-241](https://developer.apple.com/videos/play/wwdc2025/241/); [WWDC24 session 10061](https://developer.apple.com/videos/play/wwdc2024/10061/)
- Comparison of offer codes versus win-back and promotional offers (third-party guide). — [Sonar blog](https://trysonar.app/blog/apple-subscription-offers-compared)
- Competitor pricing reference: AimPool Premium Annual at $19.99 with a 7-day trial gates the photo-analysis feature. — [App Store](https://apps.apple.com/app/id6789332083)
- WWDC26 added official Unity plug-ins for StoreKit. This is irrelevant to the native app, but signals that StoreKit 2 is stable. — [iClarified](https://www.iclarified.com/101143/apple-unveils-new-ai-frameworks-and-agentic-coding-in-xcode-27)

### Inferences
- **Pack design:** sell table, cloth and cue cosmetics and drill packs as non-consumables, and a "Coach/Pro" tier (AI coach, photo import, Watch stroke analysis) as an auto-renewable subscription. Offer codes for non-consumables enable pool-hall and club partnerships and giveaways.
- Use `appTransactionID` as the anonymous account key for the relay server, without needing a login.
- Restore purchases (`AppStore.sync`) and `Transaction.updates` listening remain mandatory for review.
- **[not re-verified] Policy:** App Store Review Guideline 3.1.1 requires IAP for digital unlocks. Since 2025, US storefront rules allow external purchase links following the Epic ruling. Verify current status before relying on it. — [App Review Guidelines](https://developer.apple.com/app-store/review/guidelines/)

### Gaps
- No StoreKit changes for iOS 27 / WWDC26 found beyond Unity plug-ins. The WWDC26 StoreKit session was not fetched.
- Current (late-2026) App Review Guideline wording on external payment links in the US and EU, and the commission tiers, were not verified this session.
- Win-back offer OS minimum (believed iOS 18) was not re-verified.

# Evidence-based cue-sports training and engagement/retention design for skill-training apps (as of Nov 2026)

Scope note: 19 tool calls. Several primary sources (PMC, HFES paper full text, BU rating table, Chess.com price page) could not be fully read (captcha, paywall or image-only). Those are listed under Gaps rather than filled from memory.

## What do coaches and research say improves aiming and position play?

### Takeaway
The strongest peer-reviewed evidence specific to billiards is on the quiet eye: skilled players fixate the target longer before the stroke, and cutting that fixation short makes everyone miss more. Aiming systems (ghost ball, fractional, CTE) have no controlled-trial support. The best-known technical authority, Dr. Dave Alciatore, treats them as aids to a consistent pre-shot routine and says practice is the real "aiming system." Standardized skill exams exist (Billiard University), so the app has a ready template for a skill test.

### Cited Findings
- **Quiet eye in billiards (strong evidence, peer-reviewed).** Williams, Singer & Frehlich, *Journal of Motor Behavior* 2002, 34(2):197–207, tested 12 skilled and 12 less-skilled billiards players.
  - Skilled players held a longer final fixation on the target before starting the stroke (the quiet eye).
  - Quiet eye got longer as shots got harder.
  - For both groups it was proportionally longer on made shots than on misses.
  - In Experiment 2, time constraints shortened the quiet eye, and performance dropped at every skill level. The authors read this as quiet eye being a critical period for programming the movement.
  - Sources: [informahealthcare abstract](https://informahealthcare.com/doi/abs/10.1080/00222890209601941); [PDF copy](https://www.andrews.edu/~rbailey/Chapter%206/Motor%20Skills/6837246.pdf)
- **Quiet eye is trainable, but gains may fade (moderate evidence, non-billiards).** Klostermann & Hossner, *Frontiers in Psychology* 2018, used a far-aiming throwing task (N=29, 10 sessions).
  - Quiet eye got longer from pretest to post-test (F=5.09, ηp²=0.16), then fell back to baseline at the retention test.
  - Throwing performance improved and stayed improved (ηp²=0.52).
  - The authors suggest that explicit guidance, such as keeping the head still, may be needed for quiet-eye gains to last.
  - The paper also restates the general finding that experts show longer quiet eye than near-experts and novices (the "efficiency paradox").
  - Source: [Frontiers PDF](https://www.frontiersin.org/articles/10.3389/fpsyg.2018.00104/pdf)
- **Aiming systems (expert opinion, not experimental).** Dr. Dave Alciatore (Billiards Digest, June 2011):
  - Systems are formal procedures that lead you to the aim line. Fractional systems (Houle 3-angle, CTE, SAM) rely on a few reference lines (¼-ball = 48.6°, ½-ball = 30°, ¾-ball = 14.5°), so they need adjustment across the full range of shots.
  - Throw, squirt and swerve all require compensation.
  - Their real value is a consistent pre-shot routine and better focus. "No silver bullet": practice is the best aiming system, and he warns against marketing that overpromises.
  - Source: [Billiards Digest June 2011 PDF](https://billiards.colostate.edu:443/bd_articles/2011/june11.pdf)
- **CTE / aiming-system debate.** It continues on forums (AZB threads "A reality check on aiming systems of all kinds"), and Dr. Dave published further columns in 2024 and 2026. These are opinion and anecdote, not controlled evidence. Sources: [AZB thread](https://forums.azbilliards.com/goto/post?id=6925113), [BD Feb 2024 PDF](https://billiards.colostate.edu:443/bd_articles/2024/feb24.pdf), [BD May 2026 PDF](https://drdavepoolinfo.com/bd_articles/2026/may26.pdf) (content not reviewed in detail).
- **Standardized skill test: Billiard University playing-ability exams.**
  - The exams have two parts: Exam I (Fundamentals) and Exam II (Skills).
  - The combined score maps to a BU rating through a comparison table against "other traditional rating and handicapping systems."
  - Dr. Dave notes that with practice some drills turn into tests of execution rather than of overall playing ability.
  - Sources: [drdavepoolinfo BU rating](https://drdavepoolinfo.com/?p=2400); [BD Dec 2020 PDF](https://billiards.colostate.edu:443/bd_articles/2020/dec20.pdf); [AZB BU score thread](https://forums.azbilliards.com/goto/post?id=4209750)
- **Practice-based improvement in real billiards (strong, lab study).** The Haar/Faisal group (Imperial College) studied real-table pool learning in "Motor learning in real-world pool billiards." It is listed in the repository, but the full text was not reviewed. Source: [Spiral Imperial](https://spiral.imperial.ac.uk/entities/publication/ebae5122-9f32-4550-93b9-89b901320c11)

### Inferences
- **Quiet eye feature.** Training a stable final fixation on the target before the stroke is the most evidence-backed perceptual feature the app can offer. Ideas:
  - A "quiet-eye timer", or a pre-shot routine in which the user must hold the aim for X ms before the shot is allowed.
  - Progressively harder cut angles, since quiet eye scales with difficulty.
  - On real devices, eye tracking (ARKit face/eye tracking on iPad) could measure fixation. Unverified feasibility.
- **Aiming systems as content, not as aids.** Teach ghost ball and fractional references as a contact-point and reference-angle curriculum, with a test mode that hides all aids. This fits the project rule of no aiming help in the main mode.
- **Compensation drills.** Throw, squirt and swerve are explicitly the hard part, so the custom physics engine's spin effects can carry dedicated drills (e.g. "slow stun at 30° throw-compensation").
- **Skill exam.** A BU-style two-part exam with a numeric rating gives a credible benchmark to measure progress and to sell premium analytics.

### Gaps
- No controlled study found that compares aiming systems (CTE vs ghost ball vs fractional) on accuracy.
- The BU rating table and its mapping to Fargo were not accessible (image only). The Fargo-to-BU correspondence is unverified.
- Bert Kinister and Joe Tucker drill programs, the PBIA/ACS curriculum, and Fargo methodology were not researched within the budget.
- No 2020–2026 billiards-specific quiet-eye training intervention study (one that trains QE and measures pocketing) was found.
- Diamond systems for kicks and banks were not covered.

## Does simulator / perceptual training transfer to the real table?

### Takeaway
Evidence for transfer from screen or VR to the real table is thin. The best-documented work (Haar, Sundar & Faisal 2021) validated VR ball physics against real trajectories and found learning trends comparable to real pool. It did not run a direct VR→real transfer test. A haptic mixed-reality pool study (HFES 2019, N=38) measured transfer, but its results could not be accessed. Claims that the app "improves real play" should be framed cautiously.

### Cited Findings
- **Haar, Sundar & Faisal, PLoS One 2021, 16(1):e0245717 ("Embodied virtual reality for the study of real-world motor learning").**
  - Participants held a physical cue and struck a physical ball while seeing the scene only in VR.
  - Virtual ball trajectories were validated against real ones.
  - Short-term learning in VR showed trends "comparable" to their earlier physical billiards results.
  - The authors note that VR→real transfer is currently limited in rehabilitation, possibly because of a lack of embodiment.
  - There was no direct transfer test.
  - Sources: [Imperial Spiral](https://spiral.imperial.ac.uk/entities/publication/2df4f08c-1056-498e-9a57-dce2cdc39afb); [PMC7840008](https://pmc.ncbi.nlm.nih.gov/articles/PMC7840008)
- **"How Haptic Feedback in a Mixed Reality Pool Game Affects Real-Life Pool Performance"** (HFES Proceedings 2019, DOI 10.1177/1071181319631294).
  - Design: 2×4 mixed factorial (haptic vs no haptic × 4 shot types), 40 real shots before and after video-game practice, N=38.
  - Results were not available in the abstract page fetched.
  - Source: [sciencegate](https://www.sciencegate.app/document/10.1177/1071181319631294)
- **Quiet eye gains in a lab aiming task did not persist at retention without extra guidance** (see Q1). This suggests perceptual-training effects can be transient. Source: [Frontiers 2018](https://www.frontiersin.org/articles/10.3389/fpsyg.2018.00104/pdf)

### Inferences
- **Train cognition, not motor feel.** A phone/tablet simulator cannot train the stroke itself, so the plausible transfer targets are cognitive and perceptual:
  - contact-point and cut-angle recognition
  - path prediction (tangent line, 30° rule, rebound angles)
  - pattern and position planning
  - spin and throw expectations

  These match the app's "eye, thinking and prediction" positioning better than any claim of stroke improvement.
- **Feature: "Play this at the table" bridge.** Export a simulator drill as a real-table layout, then let the user log their real results. This builds the app's own transfer evidence and lets users see it.
- **Physics validation as a marketing asset.** The Haar et al. approach suggests publishing validation of the C++ physics against real trajectories. This needs measurement data.

### Gaps
- Results of the HFES 2019 haptic pool transfer study are unknown.
- No 2020–2026 RCT was found on mobile or 2D pool game practice transferring to real pocketing. Searches did not surface any for YouVR Pool, Pool Nation or VR Pool Sim.
- Perceptual-cognitive training transfer from other sports (e.g. NeuroTracker, video-based anticipation training) was not researched within budget.

## Engagement mechanics that work in skill-training apps (with data)

### Takeaway
The best-documented data come from Duolingo. Optimizing current-user retention (CURR) drove 4.5× DAU growth over four years. Leaderboards added +17% learning time and tripled highly engaged learners, and streak work nearly tripled the share of DAU on a 7+ day streak. Copying mechanics without adapting them failed: a referral program added only +3% new users, and a gamification counter had no effect. Billiards competitor DrillRoom uses a similar toolkit: monthly community challenges, shareable drills, progress heatmaps and personalized recommendations.

### Cited Findings
- **Duolingo, per former CPO Jorge Mazal** (Lenny's Newsletter, 28 Feb 2023):
  - DAU grew 4.5× over four years, after growth had slowed to single digits by mid-2018.
  - CURR rose 21%, and daily churn among the best users fell more than 40%.
  - In their model, CURR had about 5× the DAU impact of the next-best lever.
  - **Leaderboards:** +17% learning time, ×3 highly engaged learners (1+ hour/day, 5 days/week), and statistically significant D1/D7 gains. Lessons: match leaderboard opponents by engagement level, and keep it simple.
  - **Streaks:** the share of DAU with a 7+ day streak nearly tripled to over half of DAU. Users who reach a 10-day streak drop off far less, but Mazal flags this as partly selection bias.
  - **Notifications:** guard the channel, because excess push or email causes permanent opt-outs.
  - **Failures:** the referral program gave only +3% new users, and a gamification moves counter had no measurable effect.
  - Source: [Lenny's Newsletter](https://lennysnewsletter.com/p/how-duolingo-reignited-user-growth)
- **Streak features elsewhere.** Duolingo reached a record 17M DAU (June 2023), credited to streaks. Busuu sessions rose 15% the month after it added streaks. Source: [Sensor Tower](https://sensortower.com/blog/duolingo-streak-feature-app-engagement-growth); [Business of Apps](https://www.businessofapps.com/news/duolingos-streak-feature-drives-record-17-million-daus)
- **Recent Duolingo scale.** Coverage of the Q2 2026 earnings call exists, and a third-party summary reports 58.7M DAU with "retention hits record 84%". Not verified against the primary shareholder letter. Sources: [MarketBeat Q2 2026](https://www.marketbeat.com/instant-alerts/duolingo-q2-earnings-call-highlights-2026-08-05/); [pulse2](https://pulse2.com/duolingo-daily-active-users-reach-58-7-million-as-retention-hits-record-84-and-social-accounts-top-1-billion-organic-impressions/)
- **Lenny's podcast with Jackson Shuttleworth** (Duolingo streak/retention PM) covers streak design in depth: streak freeze, streak repair and similar. It was not transcribed here. Source: [Lenny's](https://lennysnewsletter.com/p/behind-the-product-duolingo-streaks)
- **DrillRoom v3.0** (billiards competitor, Nov 2024 release):
  - Shareable drills (private link or public), tags and favorites.
  - Drill editor that builds a layout from photos.
  - Monthly community challenges and a shot clock.
  - Apple Watch real-time scoring.
  - Performance reports: progress charts, shot-pattern analysis, pocketing-zone heatmaps, and personalized recommendations from statistical analysis.
  - Business model: a free drill editor plus a subscription platform for analytics-enhanced training.
  - Source: [AZBilliards](https://azbilliards.com/?p=235407); app listing [App Store](https://apps.apple.com/app/id1539827505)
- **Mechanics adapted from games.** A 2025 Deconstructor of Fun teardown describes how Duolingo applies game principles to grow DAU. Not read in full. Source: [Deconstructor of Fun](https://www.deconstructoroffun.com/blog/2025/4/14/duolingo-how-the-15b-app-uses-gaming-principles-to-supercharge-dau-growth)

### Inferences
- **North-star metric.** Use returning-user retention (CURR-style) rather than installs.
- **Priority features:**
  1. A daily short drill set (3–5 min) with a streak and a streak freeze.
  2. Weekly leagues grouped by activity level and skill rating, not global leaderboards.
  3. An adaptive difficulty ladder (e.g. cut angle, distance, position target size) driven by a skill rating. The BU-style exam can seed the rating.
  4. Async "ghost" challenges: the same layout and seed, compare scores. The deterministic C++ physics makes this cheap and fair.
  5. Analytics heatmaps, as DrillRoom does.
- **Retention-friendly spaced repetition.** Resurface shot types the user misses often. This is an inference from spaced-practice principles, not tested in pool.
- **Avoid copying mechanics blindly.** Duolingo's referral and moves-counter failures are a caution against that.

### Gaps
- No published retention numbers were found for Chess.com puzzles, HomeCourt, golf launch-monitor apps or DrillRoom.
- No sources were found on pool-specific app retention (D1/D7/D30) benchmarks.
- Spaced-repetition evidence for motor or perceptual sports skills was not researched within budget.

## How premium tiers are packaged in comparable sports/skill apps

### Takeaway
The pattern is free core plus a paid tier for analytics, unlimited content and coaching. DrillRoom gives away its drill editor and sells analytics-enhanced training. Chess.com uses tiered memberships (Gold / Platinum / Diamond) with limits on free puzzles and lessons. Exact 2026 prices were not verified in this pass.

### Cited Findings
- **DrillRoom:** a free drill editor plus a subscription for analytics-enhanced training. Prices are not stated in the press release. Source: [AZBilliards](https://azbilliards.com/?p=235407)
- **Chess.com tiers.** The tiers are Gold, Platinum and Diamond, with documented differences across puzzles, lessons and game review. There are user complaints about puzzle limits on lower tiers, and a price change announcement says prices changed for new premium members on 1 Sept. Specific current prices were not fetched. Sources: [Chess.com support](https://support.chess.com/en/articles/8562418-what-are-the-differences-between-membership-types); [puzzle-limit forum](https://www.chess.com/forum/view/help-support/gold-membership-puzzle-limit); [price change article](https://www.chess.com/article/view/prices-changing)
- **Digital Pool**, a pool-shot software product, launched a paid version. Details not read. Source: [AZBilliards](https://azbilliards.com/?p=231339)

### Inferences
- **Suggested split for ZokerPoolTrainer:**
  - **Free:** core practice and daily challenge, a limited exam, async challenges.
  - **Paid packs (IAP):** themed drill curricula (banks/kicks/diamond systems, spin/throw compensation, position patterns), each a one-time purchase.
  - **Subscription:** analytics, history, adaptive plans and unlimited exams/ghost challenges.

  This mirrors the DrillRoom and Chess.com split between content and analytics.
- **Fairness.** Users tend to resent paywalls on the core daily loop. Chess.com forum complaints about puzzle limits are anecdotal evidence of this.

### Gaps
- Exact 2026 prices for Chess.com, DrillRoom, HomeCourt and golf apps (e.g. Arccos, Rapsodo) were not verified.
- No data was found on subscription vs lifetime conversion in sports apps.
- r/billiards sentiment on pricing was not researched within budget.

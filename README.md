# FanOutPlanner

**Multi-agent orchestration is a topology decision.** This package reads the dependency
graph of a piece of agent work, prices what coordination actually costs, and tells you
whether fanning out across several agents beats one agent doing it serially.

Usually it doesn't.

![Title card. The formula p* = penalty / (penalty + gain) beside a callout reading "The token premium is not in here. It is a toll, not a trade." Three verdict cards: iOS inner loop, width 1, stay single-agent; Feature ship, width 2, too close to call; Module audit, width 6, fan out.](docs/header.png)


## The result worth knowing

The share of your token volume that has to be genuinely parallelisable before fan-out
breaks even on wall-clock has a closed form:

```
p* = penalty / (penalty + gain)
```

The token premium — the 4.3× you pay for inter-agent chatter — **does not appear in it.**
It is a toll, not a trade. You pay it whether or not the topology ever pays you back.

## What's in it

| Type | What it does |
| --- | --- |
| `TaskNode` / `TaskGraph` | A validated, acyclic graph. Cycles, dangling deps, self-deps and duplicate ids are rejected in `init` via typed `throws(GraphError)`, so no `TaskGraph` value can exist in a broken state. |
| `TopologyMetrics` | `maxWidth` (lanes available), `parallelShare` (token volume on wide levels), `criticalPathTokens` (the wall-clock floor no amount of agents can beat). |
| `CoordinationModel` | The three numbers you are meant to re-measure: `tokenPremium`, `parallelGainCeiling`, `sequentialPenalty`. Ships `.optimistic` and `.pessimistic` ends of the published 2026 bands. |
| `FanOutPlanner.plan(for:model:)` | Returns a `Verdict` — `.fanOut(lanes:)` or `.staySingleAgent(.noLanes / .belowBreakEven)` — plus both sides of the trade. |
| `Fixtures` | Three real shapes: the iOS inner loop, a wide module audit, and the mixed feature-ship case that flips verdict on the coefficients alone. |

Nodes are placed by their **longest** dependency chain, not their shortest — otherwise a
node that also depends on a deep predecessor would look schedulable before the thing it
waits on. `TaskGraphTests.testNodeIsPlacedByLongestChainNotShortest` pins that.

## The three fixtures, as the library computes them

| Graph | Lanes | Parallel share | Break-even needs | Verdict | Wall-clock | Tokens |
| --- | --- | --- | --- | --- | --- | --- |
| iOS inner loop | 1 | 0% | never pays | stay single-agent | 1.39× | 4.3× |
| Feature ship | 2 | 50% | 43.8% | fan out (barely) | 0.95× | 4.3× |
| Feature ship *(pessimistic)* | 2 | 50% | 58.3% | stay single-agent | 1.10× | 4.6× |
| Module audit | 6 | 90% | 32.5% | fan out | 0.31× | 4.3× |

![Line chart, "The break-even ladder". Required parallel share falls from 44% at two lanes to 32.5% from six lanes onward, where the 0.81 ceiling clamps it. Above the curve is shaded green, "fan-out pays"; below is red, "stay single-agent". The one-lane column is unshaded because no break-even exists there. The three fixtures are plotted against the curve.](docs/break-even-ladder.png)

The same feature-ship graph flips verdict on the coefficients alone. That is the argument
for measuring your own single-agent baseline before you pick a topology, and
`FanOutPlannerTests.testFeatureShipFlipsVerdictUnderThePessimisticModel` is the test.

## Using it

```swift
import FanOutPlanner

let graph = try TaskGraph([
    TaskNode(id: "patch",  title: "Apply the change",  tokens: 4_000),
    TaskNode(id: "build",  title: "Compile",           tokens: 6_000, dependsOn: ["patch"]),
    TaskNode(id: "verify", title: "Drive the UI flow", tokens: 9_000, dependsOn: ["build"]),
    TaskNode(id: "fix",    title: "Produce the patch", tokens: 7_000, dependsOn: ["verify"]),
])

let plan = FanOutPlanner.plan(for: graph, model: .optimistic)
print(plan.summary)
// Stay single-agent: the graph is a 4-step chain with no lanes.
// Fan-out would cost 4.3× tokens to run 1.39× wall-clock.
```

Replace `.optimistic` with your own measured numbers. The defaults are seeded from
published 2026 figures, not from your codebase, and the whole point of putting them in a
struct is that they are yours to establish.

## How to run it

```bash
git clone https://github.com/rajatslakhina/fanout-topology-article-demo.git
cd fanout-topology-article-demo
open Demo.xcodeproj      # pick any Simulator, Build & Run
```

No second repo, no package resolution step — `Demo.xcodeproj` consumes the library through
an `XCLocalSwiftPackageReference` pointing at this same directory. The shared `Demo` scheme
is committed, so it is selectable on a fresh clone.

Library only, no Xcode needed:

```bash
swift build && swift test
```

## Verification status

- `swift build` — **clean**, Swift 6.0.3, Linux aarch64.
- `swift test` — **33 of 33 passing.** Every number the library computes — and that the
  article quotes — is pinned by `PublishedNumbersTests`, so if the model moves, the tests
  fail and the article is wrong. That is deliberate.
- **Scope of that green build, stated precisely:** it covers the `FanOutPlanner` target.
  `Sources/FanOutPlannerUI/FanOutPlannerView.swift` is wrapped in `#if canImport(SwiftUI)`,
  so on Linux it compiles to an empty module — those lines were never type-checked here.
  `Demo/DemoApp.swift` is not a SwiftPM target at all, so `swift build` never sees it.
  Both were reviewed by hand, not compiled.
- `Demo.xcodeproj/project.pbxproj` — hand-authored and structurally checked: braces 32/32,
  parens 24/24, all 22 object ids defined, **zero dangling references and zero orphans**.
  `Package.swift` declares library targets only — no `.executableTarget`.
- **Simulator run: NOT performed this run, and no screenshot is claimed anywhere in this
  repo.** (Which is also why the UI and app code above are uncompiled: the same block.) This package was produced by an unattended scheduled job, and the desktop-control
  permission needed to drive Xcode was refused with: *"Computer-use access to 'Xcode 26.3',
  'Simulator', 'Finder' can't be approved during a scheduled run."* Rather than fake a
  screenshot, the fallback was the structural review above. The project file is sound and
  the library is tested; the on-device launch itself is unverified.

## Article

Article: (added after publish)

## Licence

MIT. See [LICENSE](LICENSE).
# FanOutPlanner

**Multi-agent orchestration is a topology decision.** This package reads the dependency
graph of a piece of agent work, prices what coordination actually costs, and tells you
whether fanning out across several agents beats one agent doing it serially.

Usually it doesn't.


## The result worth knowing

The share of your token volume that has to be genuinely parallelisable before fan-out
breaks even on wall-clock has a closed form:

```
p* = penalty / (penalty + gain)
```

The token premium — the 4.3× you pay for inter-agent chatter — **does not appear in it.**
It is a toll, not a trade. You pay it whether or not the topology ever pays you back.

## What's in it

| Type | What it does |
| --- | --- |
| `TaskNode` / `TaskGraph` | A validated, acyclic graph. Cycles, dangling deps, self-deps and duplicate ids are rejected in `init` via typed `throws(GraphError)`, so no `TaskGraph` value can exist in a broken state. |
| `TopologyMetrics` | `maxWidth` (lanes available), `parallelShare` (token volume on wide levels), `criticalPathTokens` (the wall-clock floor no amount of agents can beat). |
| `CoordinationModel` | The three numbers you are meant to re-measure: `tokenPremium`, `parallelGainCeiling`, `sequentialPenalty`. Ships `.optimistic` and `.pessimistic` ends of the published 2026 bands. |
| `FanOutPlanner.plan(for:model:)` | Returns a `Verdict` — `.fanOut(lanes:)` or `.staySingleAgent(.noLanes / .belowBreakEven)` — plus both sides of the trade. |
| `Fixtures` | Three real shapes: the iOS inner loop, a wide module audit, and the mixed feature-ship case that flips verdict on the coefficients alone. |

Nodes are placed by their **longest** dependency chain, not their shortest — otherwise a
node that also depends on a deep predecessor would look schedulable before the thing it
waits on. `TaskGraphTests.testNodeIsPlacedByLongestChainNotShortest` pins that.

## The three fixtures, as the library computes them

| Graph | Lanes | Parallel share | Break-even needs | Verdict | Wall-clock | Tokens |
| --- | --- | --- | --- | --- | --- | --- |
| iOS inner loop | 1 | 0% | never pays | stay single-agent | 1.39× | 4.3× |
| Feature ship | 2 | 50% | 44% | fan out (barely) | 0.95× | 4.3× |
| Feature ship *(pessimistic)* | 2 | 50% | 58% | stay single-agent | 1.10× | 4.6× |
| Module audit | 6 | 90% | 33% | fan out | 0.31× | 4.3× |

The same feature-ship graph flips verdict on the coefficients alone. That is the argument
for measuring your own single-agent baseline before you pick a topology, and
`FanOutPlannerTests.testFeatureShipFlipsVerdictUnderThePessimisticModel` is the test.

## Using it

```swift
import FanOutPlanner

let graph = try TaskGraph([
    TaskNode(id: "patch",  title: "Apply the change",  tokens: 4_000),
    TaskNode(id: "build",  title: "Compile",           tokens: 6_000, dependsOn: ["patch"]),
    TaskNode(id: "verify", title: "Drive the UI flow", tokens: 9_000, dependsOn: ["build"]),
    TaskNode(id: "fix",    title: "Produce the patch", tokens: 7_000, dependsOn: ["verify"]),
])

let plan = FanOutPlanner.plan(for: graph, model: .optimistic)
print(plan.summary)
// Stay single-agent: the graph is a 4-step chain with no lanes.
// Fan-out would cost 4.3× tokens to run 1.39× wall-clock.
```

Replace `.optimistic` with your own measured numbers. The defaults are seeded from
published 2026 figures, not from your codebase, and the whole point of putting them in a
struct is that they are yours to establish.

## How to run it

```bash
git clone https://github.com/rajatslakhina/fanout-topology-article-demo.git
cd fanout-topology-article-demo
open Demo.xcodeproj      # pick any Simulator, Build & Run
```

No second repo, no package resolution step — `Demo.xcodeproj` consumes the library through
an `XCLocalSwiftPackageReference` pointing at this same directory. The shared `Demo` scheme
is committed, so it is selectable on a fresh clone.

Library only, no Xcode needed:

```bash
swift build && swift test
```

## Verification status

- `swift build` — **clean**, Swift 6.0.3, Linux aarch64.
- `swift test` — **33 of 33 passing.** Every number quoted in the article and in the table
  above is pinned by `PublishedNumbersTests`, so if the model moves, the tests fail and the
  article is wrong. That is deliberate.
- `Demo.xcodeproj/project.pbxproj` — hand-authored and structurally checked: braces 32/32,
  parens 24/24, all 22 object ids defined, **zero dangling references and zero orphans**.
  `Package.swift` declares library targets only — no `.executableTarget`.
- **Simulator run: NOT performed this run, and no screenshot is claimed anywhere in this
  repo.** This package was produced by an unattended scheduled job, and the desktop-control
  permission needed to drive Xcode was refused with: *"Computer-use access to 'Xcode 26.3',
  'Simulator', 'Finder' can't be approved during a scheduled run."* Rather than fake a
  screenshot, the fallback was the structural review above. The project file is sound and
  the library is tested; the on-device launch itself is unverified.

## Article

Article: (added after publish)

## Licence

MIT. See [LICENSE](LICENSE).

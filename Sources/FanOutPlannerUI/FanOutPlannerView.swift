//  FanOutPlannerView.swift
//  Drag the penalty slider and watch a graph change its mind.

#if canImport(SwiftUI)
import SwiftUI
import FanOutPlanner

public struct FanOutPlannerView: View {
    @State private var selection: Int = 0
    @State private var sequentialPenalty: Double = 0.39

    private var model: CoordinationModel {
        CoordinationModel(
            tokenPremium: 4.3,
            parallelGainCeiling: 0.81,
            sequentialPenalty: sequentialPenalty
        )
    }

    private var graph: TaskGraph {
        let all = Fixtures.all
        guard all.indices.contains(selection) else { return Fixtures.iOSInnerLoop() }
        return all[selection].graph
    }

    private var plan: FanOutPlan { FanOutPlanner.plan(for: graph, model: model) }

    public init() {}

    public var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    picker
                    verdictCard
                    penaltyControl
                    numbersGrid
                    levelsView
                    footnote
                }
                .padding(20)
            }
            .navigationTitle("Fan-Out Planner")
        }
    }

    private var picker: some View {
        Picker("Task graph", selection: $selection) {
            ForEach(Array(Fixtures.all.enumerated()), id: \.offset) { index, entry in
                Text(entry.name).tag(index)
            }
        }
        .pickerStyle(.segmented)
    }

    private var verdictCard: some View {
        let fanOut = plan.shouldFanOut
        return VStack(alignment: .leading, spacing: 8) {
            Label(
                fanOut ? "Fan out" : "Stay single-agent",
                systemImage: fanOut ? "arrow.triangle.branch" : "arrow.down"
            )
            .font(.title2.bold())
            .foregroundStyle(fanOut ? Color.green : Color.orange)

            Text(plan.summary)
                .font(.callout)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 14)
                .fill((fanOut ? Color.green : Color.orange).opacity(0.12))
        )
    }

    private var penaltyControl: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text("Sequential penalty")
                Spacer()
                Text(String(format: "%.0f%%", sequentialPenalty * 100))
                    .monospacedDigit()
                    .foregroundStyle(.secondary)
            }
            .font(.subheadline)

            Slider(value: $sequentialPenalty, in: 0.39...0.70)

            Text("Published band for coordination overhead on sequential work.")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    private var numbersGrid: some View {
        let projection = plan.projection
        let metrics = plan.metrics
        return VStack(spacing: 0) {
            row("Lanes available", "\(metrics.maxWidth)")
            Divider()
            row("Parallel share", percent(metrics.parallelShare))
            Divider()
            row(
                "Break-even needs",
                projection.requiredParallelShare.map(percent) ?? "no lanes — never pays"
            )
            Divider()
            row("Wall-clock vs. 1 agent", String(format: "%.2f×", projection.latencyIndex))
            Divider()
            row("Token spend", String(format: "%.1f×", projection.tokenMultiple))
        }
        .padding(.vertical, 4)
        .background(RoundedRectangle(cornerRadius: 14).fill(Color.gray.opacity(0.10)))
    }

    private func row(_ label: String, _ value: String) -> some View {
        HStack {
            Text(label)
            Spacer()
            Text(value).monospacedDigit().bold()
        }
        .font(.subheadline)
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
    }

    private var levelsView: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Dependency levels")
                .font(.headline)
            ForEach(Array(graph.levels.enumerated()), id: \.offset) { index, level in
                HStack(alignment: .top, spacing: 8) {
                    Text("\(index)")
                        .font(.caption.monospacedDigit().bold())
                        .frame(width: 18, alignment: .trailing)
                        .foregroundStyle(.secondary)
                    VStack(alignment: .leading, spacing: 4) {
                        ForEach(level) { node in
                            Text(node.title)
                                .font(.caption)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(
                                    Capsule().fill(
                                        (level.count > 1 ? Color.green : Color.secondary)
                                            .opacity(0.16)
                                    )
                                )
                        }
                    }
                }
            }
        }
    }

    private var footnote: some View {
        Text("Break-even parallel share is penalty ÷ (penalty + gain). The token premium never appears in it — it is a toll, not a trade.")
            .font(.footnote)
            .foregroundStyle(.secondary)
            .fixedSize(horizontal: false, vertical: true)
    }

    /// One decimal place on purpose: the six-lane break-even is 32.5%, and rounding
    /// it to "32%" would make the running demo disagree with the published numbers.
    private func percent(_ value: Double) -> String {
        String(format: "%.1f%%", value * 100)
    }
}

#Preview {
    FanOutPlannerView()
}
#endif

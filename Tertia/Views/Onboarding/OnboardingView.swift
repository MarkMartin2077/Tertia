//
//  OnboardingView.swift
//  Tertia
//
//  Created by Mark Martin on 4/28/26.
//

import SwiftUI

struct OnboardingView: View {
    @AppStorage("hasCompletedOnboarding") private var hasCompletedOnboarding = false
    @State private var slideIndex = 0

    private let totalSlides = 5

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Spacer()
                if slideIndex < totalSlides - 1 {
                    Button("Skip", action: complete)
                        .padding(.horizontal)
                        .padding(.top, 12)
                } else {
                    Color.clear.frame(height: 36)
                }
            }

            TabView(selection: $slideIndex) {
                WelcomeSlide().tag(0)
                RuleSlide().tag(1)
                ValidSetsSlide().tag(2)
                NonSetsSlide().tag(3)
                ReadySlide(onStart: complete).tag(4)
            }
            .tabViewStyle(.page(indexDisplayMode: .always))
            .indexViewStyle(.page(backgroundDisplayMode: .always))
        }
    }

    private func complete() {
        hasCompletedOnboarding = true
    }
}

// MARK: - Slides

private struct WelcomeSlide: View {
    var body: some View {
        VStack(spacing: 24) {
            Spacer()
            Text("Welcome to Tertia")
                .font(.largeTitle.bold())
                .multilineTextAlignment(.center)
            Text("A pattern-matching game with 81 cards across four attributes.")
                .font(.body)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)

            HStack(spacing: 10) {
                ExampleCard(card: SetCard(shape: .circle, count: .one, color: .red, fill: .filled))
                ExampleCard(card: SetCard(shape: .square, count: .two, color: .green, fill: .empty))
                ExampleCard(card: SetCard(shape: .triangle, count: .three, color: .blue, fill: .rightHalf))
            }
            .padding(.horizontal, 40)

            Spacer()
            Spacer()
        }
    }
}

private struct RuleSlide: View {
    var body: some View {
        VStack(spacing: 20) {
            Spacer()
            Text("What Makes a Set")
                .font(.largeTitle.bold())
                .multilineTextAlignment(.center)
            Text(.init("Three cards form a set if, for each attribute, the values are **all the same** or **all different**."))
                .font(.body)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)

            VStack(alignment: .leading, spacing: 14) {
                attributeRow(icon: "square.on.circle", name: "Shape", values: "Circle · Square · Triangle")
                attributeRow(icon: "number", name: "Count", values: "One · Two · Three")
                attributeRow(icon: "paintpalette", name: "Color", values: "Red · Green · Blue")
                attributeRow(icon: "drop", name: "Fill", values: "Empty · Half · Filled")
            }
            .padding(20)
            .background(Color.secondary.opacity(0.1), in: .rect(cornerRadius: 16))
            .padding(.horizontal, 24)

            VStack(alignment: .leading, spacing: 8) {
                Label {
                    Text(.init("**Each attribute is checked separately.** A set can be all-same on color and all-different on shape — that's fine."))
                } icon: {
                    Image(systemName: "info.circle.fill").foregroundStyle(.tint)
                }
                Label {
                    Text(.init("**Quick check:** if you can sort the three into \"two of one, one of another\" on any attribute, it's *not* a set."))
                } icon: {
                    Image(systemName: "lightbulb.fill").foregroundStyle(.yellow)
                }
            }
            .font(.footnote)
            .padding(.horizontal, 28)

            Spacer()
        }
    }

    private func attributeRow(icon: String, name: String, values: String) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .foregroundStyle(.tint)
                .frame(width: 24)
            VStack(alignment: .leading, spacing: 2) {
                Text(name).font(.headline)
                Text(values).font(.footnote).foregroundStyle(.secondary)
            }
        }
    }
}

private struct ValidSetsSlide: View {
    var body: some View {
        VStack(spacing: 16) {
            Text("These ARE Sets")
                .font(.largeTitle.bold())
                .padding(.top, 24)

            VStack(spacing: 20) {
                ExampleTrioView(
                    cards: ExampleData.allSameSet,
                    isSet: true,
                    explanation: "All four attributes are the same.",
                    animateOnAppear: true
                )
                ExampleTrioView(
                    cards: ExampleData.allDifferentSet,
                    isSet: true,
                    explanation: "Every attribute is different.",
                    animateOnAppear: true
                )
                ExampleTrioView(
                    cards: ExampleData.mixedSet,
                    isSet: true,
                    explanation: "Different shapes and counts; same color and fill.",
                    animateOnAppear: true
                )
            }
            .padding(.horizontal, 24)

            Spacer()
        }
    }
}

private struct NonSetsSlide: View {
    var body: some View {
        VStack(spacing: 16) {
            Text("Not Sets")
                .font(.largeTitle.bold())
                .padding(.top, 24)

            Text(.init("The **\"two of one, one of another\"** trap — the most common beginner mistake."))
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)

            VStack(spacing: 28) {
                ExampleTrioView(
                    cards: ExampleData.mixedFillNonSet,
                    isSet: false,
                    explanation: "Two filled, one empty. Fill breaks the rule.",
                    animateOnAppear: true
                )
                ExampleTrioView(
                    cards: ExampleData.mixedColorNonSet,
                    isSet: false,
                    explanation: "Two red, one green. Color breaks the rule.",
                    animateOnAppear: true
                )
            }
            .padding(.horizontal, 24)

            Spacer()
        }
    }
}

private struct ReadySlide: View {
    let onStart: () -> Void

    var body: some View {
        VStack(spacing: 24) {
            Spacer()
            Image(systemName: "sparkles")
                .font(.system(size: 56))
                .foregroundStyle(.tint)
            Text("You're Ready")
                .font(.largeTitle.bold())
            Text("Find sets, score points, beat the deck.")
                .font(.body)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)

            Spacer()

            VStack(spacing: 12) {
                Button(action: onStart) {
                    Text("Start Playing")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)

                Text(.init("Revisit these rules anytime in **Settings → How to Play**."))
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 32)
        }
    }
}

#Preview {
    OnboardingView()
}

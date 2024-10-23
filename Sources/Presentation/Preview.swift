#if DEBUG
import SwiftUI

struct ParentView: View {
	@State private var isChild1Presented = true
	@State private var isChild2Presented = false
	@State private var isChild3Presented = false

	// The problem is, by design, view is following the state change
	// so after we click the button, the child 1 should be dismiss
	// and child 2 should be presented then dismiss
	// but the behavior is, child 1 is dismissed, child 2 is presented
	// NOTE: replace the `.presentation` with SwiftUI native `.sheet` there is no problem
	var body: some View {
		Rectangle()
			.foregroundStyle(Color.mint.gradient)
			.ignoresSafeArea()
			.onChange(of: isChild2Presented) { val in
				debugPrint("asd \(isChild2Presented)")
			}
			.overlay(content: {
				VStack {
					Button(action: {
						withAnimation(.spring) {
							isChild1Presented = true
						}
					}) {
						Text("Present 1")
					}

					Button(action: {
						withAnimation(.spring) {
							isChild2Presented = true
						}
					}) {
						Text("Present 2")
					}

					Button(action: {
						withAnimation(.spring) {
							isChild3Presented = true
						}
					}) {
						Text("Present 3")
					}
				}
			})
			.presentation(isPresented: $isChild1Presented) {
				ChildView()
					.overlay {
						Button(action: {
							debugPrint("dismissing child1 and present child2")
							withAnimation(.spring) {
								isChild1Presented = false
								isChild2Presented = true
							}

							// after a very quick action finished (mock running time 200ms)
							DispatchQueue.main.asyncAfter(deadline: .now() + 0.01) {
								debugPrint("dismissing child2")
								withAnimation(.spring) {
									isChild2Presented = false
								}
							}
						}) {
							Text("Dismiss then present child2")
								.foregroundStyle(Color.white)
								.font(.system(.headline))
						}
					}
			}
			.presentation(isPresented: $isChild2Presented) {
				ChildView()
			}
			.presentation(isPresented: $isChild3Presented, transition: .scale) {
				ZStack {
					Color.clear
						.contentShape(Rectangle())
						.ignoresSafeArea()
						.onTapGesture {
							withAnimation(.spring) {
								isChild3Presented.toggle()
							}
						}
					Rectangle()
						.frame(width: 100, height: 100)
						.overlay {
							Button(action: {
								withAnimation(.spring) {
									isChild3Presented.toggle()
								}
							}) {
								Text("Dismiss")
									.foregroundStyle(Color.white)
									.font(.system(.headline))
							}
						}
				}
			}
	}
}

struct ChildView: View {
	var timePublisher = Timer.publish(every: 1, on: .main, in: .common).autoconnect()
	@State var currentTime: Date = .init()

	var body: some View {
		Rectangle()
			.foregroundStyle(Color.pink.gradient)
			.ignoresSafeArea()
			.onReceive(timePublisher) { _ in currentTime = Date() }
			.overlay(alignment: .top) {
				Text("Current time: \(currentTime.description)")
					.foregroundStyle(Color.white)
					.font(.system(.headline))
					.padding(.top)
			}
	}
}

#Preview {
	ParentView()
}
#endif

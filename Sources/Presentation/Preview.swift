#if DEBUG
import SwiftUI

struct PresentationDemoView: View {
	@State private var showSheet = false
	@State private var showFullScreen = false
	@State private var showScaled = false
	@State private var showInteractive = false
	@State private var selectedItem: DemoItem?

	var body: some View {
		NavigationView {
			List {
				Section("Basic Transitions") {
					Button("Present Sheet") { showSheet = true }
					Button("Present Full Screen") { showFullScreen = true }
					Button("Present Scaled") { showScaled = true }
					Button("Present Interactive Dismiss") { showInteractive = true }
				}

				Section("Info") {
					Text("This preview demonstrates various presentation styles and interactions using the custom .presentation modifier.")
				}
			}
			.navigationTitle("Presentation Demo")
		}
		.presentation(isPresented: $showSheet) { // Default is .sheet
			PresentedView(
				title: "Sheet Presentation",
				color: .mint,
				dismissAction: { showSheet = false }
			)
		}
		.presentation(isPresented: $showFullScreen, transition: .fullScreen) {
			PresentedView(
				title: "Full Screen Presentation",
				color: .teal,
				dismissAction: { showFullScreen = false }
			) {
				// Nested Presentation Example
				NestedPresentationView()
			}
		}
		.presentation(isPresented: $showScaled, transition: .scale) {
			PresentedView(
				title: "Scale Transition",
				color: .cyan,
				dismissAction: { showScaled = false }
			)
		}
		.presentation(isPresented: $showInteractive, transition: .interactiveDismiss) {
			// Interactive dismiss works by dragging down
			PresentedView(
				title: "Interactive Dismiss",
				color: .blue,
				dismissAction: { showInteractive = false } // Can still have a button
			)
			.overlay(alignment: .bottom) {
				Text("Drag down to dismiss")
					.padding()
					.foregroundStyle(.white.opacity(0.7))
			}
		}
		.presentation(item: $selectedItem) { item in
			PresentedView(
				title: "Item \(item.id)",
				color: item.color,
				dismissAction: { selectedItem = nil }
			)
		}
	}
}

struct DemoItem: Identifiable {
	let id: Int
	let color: Color
}

struct PresentedView<Content: View>: View {
	let title: String
	let color: Color
	var dismissAction: () -> Void
	@ViewBuilder var additionalContent: Content

	// State within the presented view
	@State private var counter = 0

	init(
		title: String,
		color: Color,
		dismissAction: @escaping () -> Void,
		@ViewBuilder additionalContent: () -> Content = { EmptyView() }
	) {
		self.title = title
		self.color = color
		self.dismissAction = dismissAction
		self.additionalContent = additionalContent()
	}

	var body: some View {
		NavigationStack {
			ScrollView {
				LazyVStack {
					ZStack {
						Rectangle()
							.fill(color.gradient)
							.ignoresSafeArea()

						VStack(spacing: 20) {
							Text(title)
								.font(.largeTitle)
								.foregroundStyle(.white)

							Text("Counter: \(counter)")
								.font(.title)
								.foregroundStyle(.white)

							Button("Increment Counter") {
								counter += 1
							}
							.buttonStyle(.borderedProminent)
							.tint(.white.opacity(0.5))

							additionalContent // Add nested content here

							Button("Dismiss") {
								// Use animation matching the presentation if desired
								withAnimation(.spring) {
									dismissAction()
								}
							}
							.buttonStyle(.bordered)
							.tint(.white)
						}
						.padding()
					}

					ForEach(0 ..< 100, id: \.self) { index in
						Text("Item \(index)")
							.padding()
							.background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 12))
							.onTapGesture {
								// Example of selecting an item
								print("Selected item \(index)")
							}
					}
				}
			}
		}
		// Example: Make the presented view react to presentation state if needed
		// .onAppear { print("\(title) Appeared") }
		// .onDisappear { print("\(title) Disappeared") }
	}
}

struct NestedPresentationView: View {
	@State private var showNestedSheet = false

	var body: some View {
		VStack {
			Divider().background(.white.opacity(0.5))
			Button("Present Nested Sheet") {
				showNestedSheet = true
			}
			.buttonStyle(.bordered)
			.tint(.white)
		}
		.padding(.top)
		// Apply presentation modifier within the presented view
		.presentation(isPresented: $showNestedSheet) {
			PresentedView(
				title: "Nested Sheet",
				color: .purple,
				dismissAction: { showNestedSheet = false }
			)
		}
	}
}

#Preview {
	PresentationDemoView()
}
#endif

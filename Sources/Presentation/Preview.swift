#if DEBUG
import SwiftUI

struct PresentationDemoView: View {
	@State private var showScaled = false
	@State private var showInteractive = false
	@State private var selectedItem: DemoItem?
	@State private var showItemGrid = false
	@State private var editableItem: EditableDemoItem? = nil
	@State private var lastEditableItem: EditableDemoItem? = nil

	var body: some View {
		NavigationView {
			List {
				if let editableItem = lastEditableItem {
					VStack(alignment: .leading, spacing: 8) {
						Text("Current Item State:")
							.font(.headline)

						HStack {
							Circle()
								.fill(editableItem.color)
								.frame(width: 20, height: 20)
							Text(editableItem.title)
								.bold()
						}

						Text(editableItem.description)
							.font(.caption)
							.foregroundStyle(.secondary)

						HStack {
							Image(systemName: editableItem.icon)
							Text("Icon: \(editableItem.icon)")
								.font(.caption2)
						}
					}
					.padding()
					.background(Color.gray.opacity(0.1))
					.clipShape(RoundedRectangle(cornerRadius: 8))
				}

				Section("Basic Transitions") {
					Button("Present Scaled") { showScaled = true }
					Button("Present Interactive Dismiss") { showInteractive = true }
					Button("Present with Item") { selectedItem = DemoItem.samples[0] }
				}

				Section("Complex Examples") {
					Button("Show Item Grid") { showItemGrid = true }
				}

				Section("State Reflection Demo") {
					Button("Edit Shared Item") {
						editableItem = EditableDemoItem.sample
					}
				}

				Section("Info") {
					Text("This preview demonstrates various presentation styles and interactions using the custom .presentation modifier.")
				}
			}
			.navigationTitle("Presentation Demo")
		}
		.presentation(isPresented: $showScaled, transition: .scale) {
			PresentedView(
				title: "Scale Transition",
				color: .cyan,
				dismissAction: { showScaled = false }
			)
		}
		.presentation(
			isPresented: $showInteractive,
			transition: .interactiveFullSheet
		) {
			NavigationStack {
				// Interactive dismiss works by dragging down
				ScrollView {
					VStack(spacing: 20) {
						Text("Interactive Content")
							.font(.largeTitle)
							.padding(.top, 50)

						ForEach(0 ..< 20) { i in
							Text("Scrollable Item \(i)")
								.padding()
								.frame(maxWidth: .infinity)
								.background(Color.blue.opacity(0.1 * Double(i % 5 + 1)), in: RoundedRectangle(cornerRadius: 8))
						}

						Button(action: {
							showInteractive = false
						}) {
							Text("Dismiss by Button")
								.padding()
								.frame(maxWidth: .infinity)
								.background(Color.blue.opacity(0.8))
								.foregroundStyle(Color.white)
								.clipShape(RoundedRectangle(cornerRadius: 10))
						}
						.padding(.horizontal)
					}
					.padding()
				}
				.background(Color.blue.gradient.opacity(0.3))
				.ignoresSafeArea(edges: .bottom) // Allow content to go under home indicator for full sheet feel
				.overlay(alignment: .bottom) {
					Text("Drag down to dismiss")
						.padding()
						.foregroundStyle(.secondary)
						.frame(maxWidth: .infinity)
						.background(.ultraThinMaterial)
				}
				.navigationTitle("Interactive")
				.navigationBarTitleDisplayMode(.inline)
				.toolbar { // Example of adding a toolbar item, common in sheets
					ToolbarItem(placement: .confirmationAction) {
						Button("Done") {
							showInteractive = false
						}
					}
				}
			}
		}
		.presentation(
			item: $selectedItem,
			transition: .interactiveFullSheet
		) { item in
			ItemDetailView(item: item, dismissAction: { selectedItem = nil })
		}
		.presentation(
			isPresented: $showItemGrid,
			transition: .interactiveFullSheet
		) {
			ItemGridView(onSelectItem: { item in
				showItemGrid = false
				DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
					selectedItem = item
				}
			})
		}
		.presentation(
			item: $editableItem,
			transition: .interactiveFullSheet
		) { editableItem in
			EditItemView(item: editableItem, dismissAction: {
				lastEditableItem = editableItem
				self.editableItem = nil
			})
		}
	}
}

struct DemoItem: Identifiable {
	let id: Int
	let color: Color
	let title: String
	let description: String
	let icon: String

	static let samples = [
		DemoItem(id: 1, color: .orange, title: "Orange Item", description: "A bright orange item with details", icon: "star.fill"),
		DemoItem(id: 2, color: .blue, title: "Blue Item", description: "A cool blue item with information", icon: "heart.fill"),
		DemoItem(id: 3, color: .green, title: "Green Item", description: "A fresh green item with data", icon: "leaf.fill"),
		DemoItem(
			id: 4,
			color: .purple,
			title: "Purple Item",
			description: "A royal purple item with features",
			icon: "wand.and.stars"
		),
	]
}

class EditableDemoItem: ObservableObject, Identifiable {
	let id: Int
	@Published var color: Color
	@Published var title: String
	@Published var description: String
	@Published var icon: String

	init(id: Int, color: Color, title: String, description: String, icon: String) {
		self.id = id
		self.color = color
		self.title = title
		self.description = description
		self.icon = icon
	}

	static let sample = EditableDemoItem(
		id: 5,
		color: .red,
		title: "Editable Item",
		description: "This item can be edited from child views",
		icon: "pencil.circle.fill"
	)
}

struct PresentedView<Content: View>: View {
	let title: String
	let color: Color
	var dismissAction: () -> Void
	@ViewBuilder var additionalContent: Content
	@State var isPresented: Bool = false

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
				Button("Present Nested Sheet") {
					isPresented = true
				}
				.sheet(isPresented: $isPresented) {
					NestedPresentationView()
				}

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

struct ItemDetailView: View {
	let item: DemoItem
	let dismissAction: () -> Void

	@State private var isFavorite = false
	@State private var showNotes = false
	@State private var notes = ""

	var body: some View {
		NavigationStack {
			ScrollView {
				VStack(spacing: 20) {
					Image(systemName: item.icon)
						.font(.system(size: 60))
						.foregroundStyle(item.color)
						.padding()
						.background(.ultraThinMaterial, in: Circle())
						.padding(.top, 40)

					Text(item.title)
						.font(.largeTitle)
						.bold()

					Text(item.description)
						.font(.title3)
						.multilineTextAlignment(.center)
						.padding(.horizontal)

					Divider()

					HStack(spacing: 30) {
						Button {
							isFavorite.toggle()
						} label: {
							VStack {
								Image(systemName: isFavorite ? "heart.fill" : "heart")
									.font(.system(size: 24))
									.foregroundStyle(isFavorite ? .red : .gray)
								Text("Favorite")
									.font(.caption)
							}
						}

						Button {
							showNotes.toggle()
						} label: {
							VStack {
								Image(systemName: "note.text")
									.font(.system(size: 24))
								Text("Notes")
									.font(.caption)
							}
						}

						ShareLink(item: "Sharing Item #\(item.id): \(item.title)") {
							VStack {
								Image(systemName: "square.and.arrow.up")
									.font(.system(size: 24))
								Text("Share")
									.font(.caption)
							}
						}
					}
					.padding()
					.buttonStyle(.plain)

					if showNotes {
						VStack(alignment: .leading) {
							Text("Notes")
								.font(.headline)

							TextEditor(text: $notes)
								.frame(height: 150)
								.padding(4)
								.background(
									RoundedRectangle(cornerRadius: 8)
										.stroke(Color.gray.opacity(0.3), lineWidth: 1)
								)
						}
						.padding()
						.transition(.move(edge: .bottom).combined(with: .opacity))
						.animation(.spring, value: showNotes)
					}

					Button("Dismiss") {
						dismissAction()
					}
					.buttonStyle(.borderedProminent)
					.tint(item.color)
					.padding(.top, 20)
				}
				.padding()
			}
			.background(item.color.opacity(0.1))
			.navigationTitle("Item Details")
			.navigationBarTitleDisplayMode(.inline)
			.toolbar {
				ToolbarItem(placement: .topBarTrailing) {
					Menu {
						Button("Edit", action: {})
						Button("Duplicate", action: {})
						Button("Delete", role: .destructive, action: {})
					} label: {
						Image(systemName: "ellipsis.circle")
					}
				}
			}
		}
	}
}

struct ItemGridView: View {
	let onSelectItem: (DemoItem) -> Void
	@State private var searchText = ""
	@State private var gridColumns = [GridItem(.adaptive(minimum: 160))]

	var filteredItems: [DemoItem] {
		if searchText.isEmpty {
			return DemoItem.samples
		} else {
			return DemoItem.samples.filter { $0.title.localizedCaseInsensitiveContains(searchText) }
		}
	}

	var body: some View {
		NavigationStack {
			ScrollView {
				LazyVGrid(columns: gridColumns, spacing: 16) {
					ForEach(filteredItems) { item in
						ItemCard(item: item)
							.onTapGesture {
								onSelectItem(item)
							}
					}
				}
				.padding()
			}
			.searchable(text: $searchText, prompt: "Search items")
			.navigationTitle("Item Grid")
			.toolbar {
				ToolbarItem(placement: .topBarTrailing) {
					Button {
						withAnimation {
							if gridColumns.count == 1 {
								gridColumns = [GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible())]
							} else {
								gridColumns = [GridItem(.adaptive(minimum: 160))]
							}
						}
					} label: {
						Image(systemName: gridColumns.count == 1 ? "square.grid.3x3" : "rectangle.grid.1x2")
					}
				}
			}
		}
	}
}

struct ItemCard: View {
	let item: DemoItem

	var body: some View {
		VStack(spacing: 12) {
			Image(systemName: item.icon)
				.font(.system(size: 30))
				.foregroundStyle(.white)
				.frame(width: 60, height: 60)
				.background(item.color, in: RoundedRectangle(cornerRadius: 12))

			Text(item.title)
				.font(.headline)
				.lineLimit(1)

			Text(item.description)
				.font(.caption)
				.foregroundStyle(.secondary)
				.lineLimit(2)
				.multilineTextAlignment(.center)
		}
		.padding()
		.frame(maxWidth: .infinity)
		.background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16))
		.overlay(
			RoundedRectangle(cornerRadius: 16)
				.stroke(item.color.opacity(0.6), lineWidth: 1)
		)
	}
}

struct EditItemView: View {
	@ObservedObject var item: EditableDemoItem
	let dismissAction: () -> Void

	@State private var selectedColor: Color
	@State private var title: String
	@State private var description: String
	@State private var showIconPicker = false

	// Available icons for selection
	let availableIcons = [
		"pencil.circle.fill", "star.fill", "heart.fill", "leaf.fill",
		"wand.and.stars", "bolt.fill", "flame.fill", "drop.fill",
	]

	init(item: EditableDemoItem, dismissAction: @escaping () -> Void) {
		self.item = item
		self.dismissAction = dismissAction

		// Initialize state with current values
		_selectedColor = State(initialValue: item.color)
		_title = State(initialValue: item.title)
		_description = State(initialValue: item.description)
	}

	var body: some View {
		NavigationStack {
			Form {
				Section("Item Details") {
					TextField("Title", text: $title)
						.onChange(of: title) { newValue in
							item.title = newValue
						}

					TextEditor(text: $description)
						.frame(height: 100)
						.onChange(of: description) { newValue in
							item.description = newValue
						}
				}

				Section("Appearance") {
					VStack(alignment: .leading) {
						Text("Color")
							.font(.headline)

						HStack {
							ForEach([Color.red, .orange, .yellow, .green, .blue, .purple, .pink], id: \.self) { color in
								Circle()
									.fill(color)
									.frame(width: 30, height: 30)
									.overlay(
										Circle()
											.stroke(selectedColor == color ? Color.white : Color.clear, lineWidth: 2)
											.padding(2)
									)
									.overlay(
										Circle()
											.stroke(selectedColor == color ? Color.black : Color.clear, lineWidth: 1)
											.padding(3)
									)
									.onTapGesture {
										selectedColor = color
										item.color = color
									}
							}
						}
					}

					VStack(alignment: .leading) {
						HStack {
							Text("Icon")
								.font(.headline)

							Spacer()

							Button {
								showIconPicker.toggle()
							} label: {
								Text("Change Icon")
									.font(.callout)
							}
						}

						if showIconPicker {
							LazyVGrid(columns: [GridItem(.adaptive(minimum: 50))], spacing: 10) {
								ForEach(availableIcons, id: \.self) { iconName in
									Button {
										item.icon = iconName
										showIconPicker = false
									} label: {
										VStack {
											Image(systemName: iconName)
												.font(.system(size: 24))
												.frame(width: 44, height: 44)
												.background(Color.gray.opacity(0.1))
												.clipShape(Circle())

											Text(iconName)
												.font(.caption2)
												.lineLimit(1)
												.truncationMode(.middle)
										}
									}
									.buttonStyle(.plain)
								}
							}
							.padding(.vertical)
						} else {
							HStack {
								Image(systemName: item.icon)
									.font(.system(size: 24))
									.foregroundColor(selectedColor)
								Text(item.icon)
							}
							.padding(.vertical, 8)
						}
					}
				}

				Section("Preview") {
					HStack {
						Image(systemName: item.icon)
							.font(.title)
							.foregroundStyle(item.color)

						VStack(alignment: .leading) {
							Text(item.title)
								.bold()
							Text(item.description)
								.font(.caption)
								.foregroundStyle(.secondary)
								.lineLimit(1)
						}
					}
					.padding()
					.frame(maxWidth: .infinity, alignment: .leading)
					.background(item.color.opacity(0.1))
					.clipShape(RoundedRectangle(cornerRadius: 8))
				}
			}
			.navigationTitle("Edit Item")
			.navigationBarTitleDisplayMode(.inline)
			.toolbar {
				ToolbarItem(placement: .cancellationAction) {
					Button("Cancel") {
						dismissAction()
					}
				}

				ToolbarItem(placement: .confirmationAction) {
					Button("Save") {
						dismissAction()
					}
				}
			}
		}
	}
}

#Preview {
	PresentationDemoView()
}
#endif

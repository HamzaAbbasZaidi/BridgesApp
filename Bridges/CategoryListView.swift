import SwiftUI
import FirebaseFirestore

struct CategoryListView: View {
    @State private var categories: [String] = []

    var body: some View {
        ZStack {
            Color(red: 0.9, green: 0.95, blue: 1.0).ignoresSafeArea()

            VStack(spacing: 24) {
                Text("Select a Category")
                    .font(.largeTitle.bold())
                    .foregroundColor(.blue)
                    .padding(.top)
                
                Text("Pick a category of conflict you're interested in exploring. You'll be shown real-life bridges being built — and suggested small acts of kindness you can join in.")
                        .font(.body)
                        .foregroundColor(.blue.opacity(0.8))
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)

                ForEach(categories, id: \.self) { category in
                    NavigationLink(destination: IssueListView(category: category)) {
                        HStack(spacing: 16) {
                            Image(systemName: icon(for: category))
                                .font(.title2)
                                .foregroundColor(.white)
                                .frame(width: 36, height: 36)
                                .background(Circle().fill(Color.blue.opacity(0.8)))

                            Text(category.capitalized)
                                .font(.headline)
                                .foregroundColor(.blue)

                            Spacer()

                            Image(systemName: "chevron.right")
                                .foregroundColor(.blue.opacity(0.5))
                        }
                        .padding()
                        .background(Color.white)
                        .cornerRadius(12)
                        .shadow(color: .gray.opacity(0.2), radius: 4, x: 0, y: 2)
                        .padding(.horizontal)
                    }
                }

                Spacer()
            }
        }
        .onAppear {
            fetchCategories()
        }
    }

    func fetchCategories() {
        let db = Firestore.firestore()
        db.collection("categories").getDocuments { snapshot, error in
            if let documents = snapshot?.documents {
                self.categories = documents.map { $0.documentID }
            }
        }
    }

    func icon(for category: String) -> String {
        switch category.lowercased() {
        case "region":
            return "globe.asia.australia"
        case "sport":
            return "sportscourt"
        default:
            return "circle.grid.2x2" // fallback icon
        }
    }
}

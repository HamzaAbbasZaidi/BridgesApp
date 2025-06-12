import SwiftUI
import Firebase
import FirebaseFirestore
import FirebaseAuth

struct MainTopicsView: View {
    @State private var selectedFilter: String = "Sport"
    @State private var issues: [Issue] = []
    @State private var loading = true
    @State private var selectedIssue: Issue? = nil
    @State private var showInterestEditor = false
    @State private var showCreateIssue = false
    @State private var userPoints: Int = 0

    init() {
            print("MainTopicsView INIT")
        }
    
    let filters = ["Region", "Sport", "My topics"]

    var body: some View {
        NavigationStack {
            ZStack {
                Color(red: 0.9, green: 0.95, blue: 1.0)
                    .ignoresSafeArea()

                VStack(spacing: 20) {
                    Text("Explore Bridges")
                        .font(.largeTitle.bold())
                        .foregroundColor(.blue)
                        .padding(.top)

                    Text("You have \(userPoints) points")
                                            .font(.subheadline)
                                            .foregroundColor(.blue)
                    
                    Text("Tap on a topic below to dive into trending conversations. Earn points by engaging positively!")
                        .font(.subheadline)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)
                        .foregroundColor(.blue.opacity(0.7))

                    // Filter buttons
                    HStack(spacing: 12) {
                        ForEach(filters, id: \.self) { filter in
                            Button(action: {
                                withAnimation(nil) {
                                    selectedFilter = filter
                                }
                                loadTopics(for: filter)
                            }) {
                                Text(filter)
                                    .padding(.vertical, 8)
                                    .padding(.horizontal)
                                    .background(Color.blue.opacity(selectedFilter == filter ? 0.9 : 0.3))
                                    .foregroundColor(.white)
                                    .cornerRadius(10)
                            }
                        }
                    }

                    // Topics + Loading view
                    ZStack {
                        if loading {
                            ProgressView()
                        }

                        ScrollView {
                            VStack(spacing: 12) {
                                ForEach(issues) { issue in
                                    Button {
                                        addIssueToSelectedIfNeeded(issue)
                                        selectedIssue = issue
                                    } label: {
                                        HStack {
                                            Text(issue.title)
                                                .fontWeight(.medium)
                                            Spacer()
                                            Image(systemName: "flame.fill")
                                            Text("\(issue.activityScore)")
                                        }
                                        .padding()
                                        .background(Color.blue.opacity(0.85))
                                        .foregroundColor(.white)
                                        .cornerRadius(12)
                                        .padding(.horizontal)
                                    }
                                }
                            }
                            .opacity(loading ? 0 : 1)
                        }
                    }

                    Button("Change My Interests") {
                        showInterestEditor = true
                    }
                    .font(.subheadline)
                    .foregroundColor(.blue)
                    .padding(.top)
                    
                    Button("Create a New Topic") {
                        showCreateIssue = true
                    }
                    .font(.subheadline)
                    .foregroundColor(.blue)
                    .padding(.top, 4)
                    
                    
                }
                .padding()
            }
            .navigationDestination(item: $selectedIssue) { issue in
                IssueDetailView(issue: issue)
                    .id(UUID()) //
            }
            
            .navigationDestination(isPresented: $showCreateIssue) {
                CreateIssueView(onSubmit: { _ in
                    NotificationCenter.default.post(name: NSNotification.Name("refreshTopics"), object: nil)
                    showCreateIssue = false
                })
            }



            .navigationDestination(isPresented: $showInterestEditor) {
                CategoryListView()
            }
            .onAppear {
                print("MainTopicsView appeared with \(issues.count) issues")
                fetchUserPoints()
                loadTopics(for: selectedFilter)
            }
            .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("refreshTopics"))) { _ in
                loadTopics(for: selectedFilter) // Refresh data after creation
            }
        }
    }

    func loadTopics(for filter: String) {
        loading = true
        issues = []

        let db = Firestore.firestore()
        guard let uid = Auth.auth().currentUser?.uid else {
            loading = false
            return
        }

        if filter == "My topics" {
            let userRef = db.collection("users").document(uid)
            userRef.getDocument { snapshot, error in
                guard let data = snapshot?.data(),
                      let selectedTitles = data["selectedIssues"] as? [String],
                      !selectedTitles.isEmpty else {
                    self.loading = false
                    return
                }

                let categories = ["region", "sport"] // add others if needed
                var allIssues: [Issue] = []
                let group = DispatchGroup()

                for category in categories {
                    group.enter()
                    db.collection("categories")
                        .document(category)
                        .collection("issues")
                        .getDocuments { snapshot, error in
                            if let docs = snapshot?.documents {
                                let matches = docs.compactMap { doc -> Issue? in
                                    let data = doc.data()
                                    let title = data["title"] as? String ?? ""
                                    guard selectedTitles.contains(title) else { return nil }
                                    return Issue(
                                        id: doc.documentID,
                                        title: title,
                                        description: data["description"] as? String ?? "",
                                        activityScore: data["activityScore"] as? Int ?? 0,
                                        category: category.capitalized
                                    )
                                }
                                allIssues.append(contentsOf: matches)
                            }
                            group.leave()
                        }
                }

                group.notify(queue: .main) {
                    self.issues = allIssues
                    self.loading = false
                }
            }

        } else {
            db.collection("categories")
                .document(filter.lowercased())
                .collection("issues")
                .getDocuments { snapshot, error in
                    if let documents = snapshot?.documents {
                        self.issues = documents.map { doc in
                                                    let data = doc.data()
                                                    
                                                    return Issue(
                                                        id: doc.documentID,
                                                        title: data["title"] as? String ?? "Untitled",
                                                        description: data["description"] as? String ?? "",
                                                        activityScore: data["activityScore"] as? Int ?? 0,
                                                        category: filter
                                                    )
                                                }

                    }
                    self.loading = false
                }
        }
    }
    
    func fetchUserPoints() {
            guard let uid = Auth.auth().currentUser?.uid else { return }
            let db = Firestore.firestore()
            db.collection("users").document(uid).getDocument { snapshot, _ in
                if let data = snapshot?.data(), let points = data["points"] as? Int {
                    self.userPoints = points
                }
            }
        }
    
    func addIssueToSelectedIfNeeded(_ issue: Issue) {
            guard let uid = Auth.auth().currentUser?.uid else { return }
            let db = Firestore.firestore()
            let userRef = db.collection("users").document(uid)

            userRef.updateData([
                "selectedIssues": FieldValue.arrayUnion([issue.title])
            ])
        }

}

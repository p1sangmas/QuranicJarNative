//
//  ContentView.swift
//  QuranJar
//
//  Created by Fakhrul Fauzi on 27/03/2025.
//

import SwiftUI
import CoreML

struct ContentView: View {
    @AppStorage("userName") private var userName: String = ""
    @AppStorage("bookmarks") private var bookmarksData: String = "[]" // Store bookmarks as a JSON string
    @State private var userInput: String = ""
    @State private var predictedEmotion: String = ""
    @State private var quranicVerse: String = ""
    @State private var isLoading: Bool = false
    @State private var bookmarks: [QuranVerse] = []
    @State private var selectedTab: Int = 0
    @State private var displayedVerse: QuranVerse?
    
    // Computed property to calculate word count
    private var wordCount: Int {
        userInput.split { $0.isWhitespace }.count
    }

    // Computed property to check if the button should be enabled
    private var isPredictButtonEnabled: Bool {
        wordCount >= 3 && !isLoading
    }

    var body: some View {
        ZStack {
            TabView(selection: $selectedTab) {
                homeTab()
                    .tabItem {
                        Label("Home", systemImage: "house")
                    }
                    .tag(0)

                BookmarkView(bookmarks: $bookmarks)
                    .tabItem {
                        Label("Bookmarks", systemImage: "bookmark")
                    }
                    .tag(1)

                NavigationView {
                    SearchView(bookmarks: $bookmarks)
                }
                .tabItem {
                    Label("Search", systemImage: "magnifyingglass")
                }
                .tag(2)

                NavigationView {
                    SettingsView(bookmarks: $bookmarks)
                }
                .tabItem {
                    Label("Settings", systemImage: "gear")
                }
                .tag(3)
            }
            .onAppear(perform: loadBookmarks)
        }
    }

    // Extracted Home Tab
    @ViewBuilder
    private func homeTab() -> some View {
        NavigationView {
            VStack(spacing: 20) {
                Spacer()

                greetingSection()

                Spacer()

                inputSection()
                    .padding(.horizontal)

                if isLoading {
                    ProgressView("Finding suitable verse...")
                        .padding()
                }

                if !predictedEmotion.isEmpty || !quranicVerse.isEmpty {
                    resultsSection()
                }
            }
            .padding()
            .navigationTitle("Quranic Jar")
            .navigationBarTitleDisplayMode(.inline)
        }
    }

    // Extracted Greeting Section
    @ViewBuilder
    private func greetingSection() -> some View {
        VStack(spacing: 10) {
            TypewriterText(text: "Assalamualaikum, \(userName)!")
                .font(.largeTitle)
                .fontWeight(.bold)
                .multilineTextAlignment(.center)
                .foregroundColor(.primary)

            Text("How are you feeling today?")
                .font(.body)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding()
    }

    // Extracted Results Section
    @ViewBuilder
    private func resultsSection() -> some View {
        VStack(spacing: 15) {
            if !predictedEmotion.isEmpty {
                VStack {
                    Text("Predicted Emotion")
                        .font(.headline)
                        .foregroundColor(.secondary)

                    Text(predictedEmotion)
                        .font(.title3)
                        .fontWeight(.semibold)
                        .foregroundColor(.primary)
                }
            }

            if !quranicVerse.isEmpty {
                VStack {
                    Text("Quranic Verse")
                        .font(.headline)
                        .foregroundColor(.secondary)

                    ScrollView {
                        VStack(spacing: 10) {
                            if let verse = displayedVerse { // Use the stored displayed verse
                                Text(verse.ayahArabic)
                                    .font(.title2)
                                    .multilineTextAlignment(.center)
                                    .foregroundColor(.primary)
                            }

                            Text(quranicVerse)
                                .font(.body)
                                .multilineTextAlignment(.center)
                                .foregroundColor(.primary)
                        }
                    }
                    .frame(maxHeight: 100)

                    HStack {
                        Spacer()
                        Button(action: {
                            if let verse = displayedVerse { // Use the stored displayed verse
                                bookmarkVerse(verse: verse)
                                let generator = UINotificationFeedbackGenerator()
                                generator.notificationOccurred(.success)
                                print("Verse successfully bookmarked!")
                            } else {
                                print("No verse to bookmark")
                            }
                        }) {
                            Image(systemName: "bookmark")
                                .font(.title2)
                                .padding(5)
                                .foregroundColor(.green)
                        }
                    }
                }
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(10)
        .shadow(color: Color.black.opacity(0.1), radius: 5, x: 0, y: 2)
    }

    private func loadBookmarks() {
        if let data = bookmarksData.data(using: .utf8) {
            let decoder = JSONDecoder()
            if let decodedBookmarks = try? decoder.decode([QuranVerse].self, from: data) {
                bookmarks = decodedBookmarks
                print("Loaded bookmarks: \(bookmarks)")
            } else {
                print("Failed to decode bookmarks")
            }
        } else {
            print("No bookmarks data found")
        }
    }

    private func saveBookmarks() {
        let encoder = JSONEncoder()
        if let encodedData = try? encoder.encode(bookmarks) {
            bookmarksData = String(data: encodedData, encoding: .utf8) ?? "[]"
        }
    }



    @ViewBuilder
    private func inputSection() -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                TextField("3-5 words on your feeling...", text: $userInput)
                    .padding(.leading)
                    .frame(height: 40)
                    .frame(maxWidth: .infinity)
                    .background(Color(.systemGray6))
                    .cornerRadius(30)
                    .multilineTextAlignment(.leading)

                Button(action: {
                    predictEmotion()
                    UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
                }) {
                    Image(systemName: "stethoscope")
                        .font(.title2)
                        .padding()
                        .background(isPredictButtonEnabled ? Color.blue : Color.gray)
                        .foregroundColor(.white)
                        .clipShape(Circle())
                }
                .disabled(!isPredictButtonEnabled) // Disable button if word count < 4
                .padding(.trailing, 5)
            }
            .background(Color(.systemGray6))
            .cornerRadius(30)
            .shadow(color: Color.black.opacity(0.1), radius: 5, x: 0, y: 2)
        }
    }


    func predictEmotion() {
        guard !userInput.isEmpty else { return }

        isLoading = true

        DispatchQueue.global(qos: .userInitiated).async {
            do {
                let model = try QuranClassifier(configuration: MLModelConfiguration())
                let prediction = try model.prediction(text: userInput)
                
                DispatchQueue.main.async {
                    self.predictedEmotion = prediction.label
                    
                    // Fetch the verse based on the predicted emotion
                    if let verse = parseQuranicVerse(prediction.label) {
                        self.quranicVerse = verse.ayahEnglish
                        self.displayedVerse = verse // Store the displayed verse
                    } else {
                        self.quranicVerse = "No verse found for the emotion: \(prediction.label)"
                        self.displayedVerse = nil
                    }
                    
                    self.isLoading = false
                }
            } catch {
                DispatchQueue.main.async {
                    print("Error during prediction: \(error.localizedDescription)")
                    self.isLoading = false
                }
            }
        }
    }

    func bookmarkVerse(verse: QuranVerse) {
        if !bookmarks.contains(where: { $0.id == verse.id }) {
            bookmarks.append(verse)
            saveBookmarks()
        }
    }
}

func parseQuranicVerse(_ emotion: String) -> QuranVerse? {
    // Path to the CSV file
    guard let csvPath = Bundle.main.path(forResource: "quran_emotions_cleaned_2", ofType: "csv") else {
        print("CSV file not found")
        return nil
    }

    do {
        // Read the CSV file content
        let csvContent = try String(contentsOfFile: csvPath, encoding: .utf8)
        let rows = csvContent.split(separator: "\n").map { $0.split(separator: ",") }

        // Collect all rows that match the emotion label
        var matchingVerses: [QuranVerse] = []

        for row in rows {
            guard row.count == 8 else { continue } // Ensure the row has all columns

            let surahNo = Int(row[0]) ?? 0
            let ayahNo = Int(row[1]) ?? 0
            let surahNameAr = String(row[2])
            let ayahAr = String(row[3])
            let label = String(row[4])
            let ayahEn = String(row[5])
            let surahNameEn = String(row[6])
            let surahNameRoman = String(row[7])

            if label.lowercased() == emotion.lowercased() {
                // Add the QuranVerse object to the matching list
                matchingVerses.append(
                    QuranVerse(
                        surahNo: surahNo,
                        ayahNo: ayahNo,
                        surahName: surahNameAr,
                        ayahArabic: ayahAr,
                        emotion: label,
                        ayahEnglish: ayahEn,
                        surahMeaning: surahNameEn,
                        surahEnglish: surahNameRoman
                    )
                )
            }
        }

        // Randomly select one verse from the matching list
        if let randomVerse = matchingVerses.randomElement() {
            return randomVerse
        }

        print("No verse found for emotion: \(emotion)")
        return nil
    } catch {
        print("Error reading CSV file: \(error.localizedDescription)")
        return nil
    }
}

struct TypewriterText: View {
    let text: String
    @State private var displayedText: String = ""
    @State private var charIndex: Int = 0

    var body: some View {
        Text(displayedText)
            .onAppear {
                displayedText = ""
                charIndex = 0
                typeText()
            }
    }

    private func typeText() {
        guard charIndex < text.count else { return }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
            displayedText.append(text[text.index(text.startIndex, offsetBy: charIndex)])
            charIndex += 1
            typeText()
        }
    }
}


struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}

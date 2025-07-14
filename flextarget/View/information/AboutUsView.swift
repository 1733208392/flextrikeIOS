//
//  AboutUsView.swift
//  Flex Target
//
//  Created by Kai Yang on 2025/7/13.
//


import SwiftUI

struct AboutUsView: View {
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                Text("About US")
                    .font(.largeTitle)
                    .fontWeight(.bold)
                    .padding(.top, 16)

                Text("Thank you for trusting us with buying our product!")
                    .font(.headline)

                Text("""
The Grwolf Smart Target is designed for shooting enthusiasts who want a convenient solution for practicing with airsoft or Laser Dry Fire at home, eliminating the hassle of going to the shooting range. Compared to the traditional target, the device has the following features:
""")
                    .font(.body)

                VStack(alignment: .leading, spacing: 8) {
                    HStack(alignment: .top) {
                        Text("•")
                        Text("Real-time hit point display allows you to track and score your shots instantly.")
                    }
                    HStack(alignment: .top) {
                        Text("•")
                        Text("Choose different drills with the same device, such as high-speed shooting and free shooting, to enhance your shooting experience.")
                    }
                }
                .font(.body)
                .padding(.leading, 8)

                Divider()

                Text("Contact Us")
                    .font(.title2)
                    .fontWeight(.semibold)

                HStack(alignment: .firstTextBaseline, spacing: 0) {
                    Text("If you have any questions or feedback, please feel free to write to ")
                        .font(.body)
                    Text("business@grwolftactical.com")
                        .font(.body)
                        .foregroundColor(.accentColor)
                        .underline()
                        .onTapGesture {
                            if let url = URL(string: "mailto:business@grwolftactical.com") {
                                UIApplication.shared.open(url)
                            }
                        }
                }

                Spacer()
            }
            .padding()
        }
        .background(Color(.systemGroupedBackground).ignoresSafeArea())
        .navigationTitle("About Us")
    }
}

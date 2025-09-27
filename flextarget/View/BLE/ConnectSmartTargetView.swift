import SwiftUI

struct ConnectSmartTargetView: View {
    @ObservedObject var bleManager: BLEManager
    @State private var statusText: String = "CONNECTING"
    @State private var showReconnect: Bool = false
    @State private var isShaking: Bool = true
    @State private var showProgress: Bool = false
    @State private var navigateToMain = false
    @State private var showInfo = false

    var body: some View {
        NavigationStack {
            GeometryReader { geometry in
                let frameWidth = geometry.size.width * 0.4
                let frameHeight = geometry.size.height * 0.35
                let dotPadding: CGFloat = 100
                let dotRadius: CGFloat = 6

                VStack(spacing: 0) {
                    //Information Button
                    HStack {
                        Button(action: { showInfo = true }) {
                            Image(systemName: "info.circle")
                                .font(.title2)
                                .foregroundColor(.white)
//                                .background(Circle().fill(Color.red))
                        }
                    }
                    .frame(width: geometry.size.width,alignment:.trailing)
                    .padding(.top, 16)
                    .padding(.trailing, 24)
                    // Main Target Frame
                    ZStack(alignment: .topLeading) {
                        Rectangle()
                            .stroke(Color.white, lineWidth: 10)
                            .frame(width: frameWidth, height: frameHeight)
                        Circle()
                            .fill(Color.red)
                            .frame(width: dotRadius * 2, height: dotRadius * 2)
                            .offset(x: dotPadding, y: dotPadding)
                    }
                    //.frame(width: .infinity, height: frameHeight, alignment: .top)
                    .padding(.top, geometry.size.height * 0.15)
//                    .border(.red, width: 1)
                    
                    // Status and Reconnect Button
                    VStack(spacing: 12) {
                        HStack(spacing: 8) {
                            Text(statusText)
                                .font(.custom("DigitalDreamFat", size: 16))
                                .foregroundColor(.white)
                                .multilineTextAlignment(.center)
                            if showProgress {
                                ProgressView()
                                    .progressViewStyle(CircularProgressViewStyle(tint: .white))
                            }
                        }
                        .padding(.horizontal, 24)
                        .padding(.vertical, 16)

                        if showReconnect {
                            Button(action: handleReconnect) {
                                Text("RECONNECT")
                                    .font(.custom("DigitalDreamFat", size: 20))
                                    .foregroundColor(.white)
                                    .frame(width: geometry.size.width * 0.75, height: 44)
                                    .background(Color(red: 223/255, green: 13/255, blue: 13/255))
                                    .cornerRadius(8)
                            }
                            .padding(.horizontal)
                        }
                    }//Status and Reconnect Button
                    .frame(maxWidth: .infinity)
                    .padding(.top, 120)
                }//Top Level VStack
                .frame(width: geometry.size.width, height: geometry.size.height, alignment: .top)
//                .border(Color.white, width: 1)
            }//Top Level Geometry Reader
            .sheet(isPresented: $showInfo) { InformationPage() }
            .background(Color.black.ignoresSafeArea())
            .onAppear { startScanAndTimer() }
            .onReceive(bleManager.$isConnected) { connected in
                if connected {
                    statusText = "CONNECTED"
                    isShaking = false
                    showReconnect = false
                    showProgress = false
                    navigateToMain = true
                }
            }
            .navigationDestination(isPresented: $navigateToMain) {
                MainPageView()
                    .toolbar(.hidden, for: .navigationBar)
                    .navigationBarBackButtonHidden(true)
            }
        }
    }

    private func startScanAndTimer() {
        statusText = "CONNECTING"
        isShaking = true
        showReconnect = false
        bleManager.startScan()
        showProgress = true
        DispatchQueue.main.asyncAfter(deadline: .now() + 30) {
            if !bleManager.isConnected {
                statusText = "TARGET NOT FOUND"
                isShaking = false
                showReconnect = true
                showProgress = false
            }
        }
    }

    private func handleReconnect() {
        startScanAndTimer()
    }
}

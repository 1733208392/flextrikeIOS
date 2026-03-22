import Foundation

class ServerConfig {

    private let userDefaults = UserDefaults.standard

    private let serverUrlKey = "serverUrl"

    static let international = "https://app.etarget.grwolftactical.com"

    static let china = "https://etarget.topoint-archery.cn"

    func getServerUrl() -> String {

        return userDefaults.string(forKey: serverUrlKey) ?? ServerConfig.international

    }

    func initializeServer() {
        if userDefaults.string(forKey: serverUrlKey) == nil {
            let identifier = Locale.current.region?.identifier ?? ""
            if identifier == "CN" {
                setServerUrl(ServerConfig.china)
            } else {
                setServerUrl(ServerConfig.international)
            }
        }
    }

    func setServerUrl(_ url: String) {

        userDefaults.set(url, forKey: serverUrlKey)

    }

    func isInternational() -> Bool {

        return getServerUrl() == ServerConfig.international

    }

    func toggleServer() {

        let current = getServerUrl()

        setServerUrl(current == ServerConfig.international ? ServerConfig.china : ServerConfig.international)

    }

}
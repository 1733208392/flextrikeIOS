import Foundation

class ServerConfig {

    private let userDefaults = UserDefaults.standard

    private let serverUrlKey = "serverUrl"

    static let international = "http://52.221.232.2"

    static let china = "http://124.222.233.30"

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
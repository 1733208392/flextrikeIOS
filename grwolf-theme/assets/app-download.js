    <script>
        var userAgent = navigator.userAgent.toLowerCase();
        if (userAgent.indexOf("iphone") !== -1 || userAgent.indexOf("ipad") !== -1) {
            window.location.href = "https://apps.apple.com/us/app/%E6%99%BA%E8%83%BD%E9%9D%B6/id6755102346";
        } else if (userAgent.indexOf("android") !== -1) {
            // Google Play Store link TBD
            window.location.href = "https://play.google.com/store/apps/details?id=TBD";
        } else {
            // For other devices, perhaps stay on page or redirect to a default page
            document.body.innerHTML = "<p>This app is available for iOS and Android devices.</p>";
        }
    </script>